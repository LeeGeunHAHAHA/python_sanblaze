#!/bin/bash

#argument input are initialized to null
numport=1                       # 1=Single Port         2=Dual Port
port=0
target=102
target2=112
pretest=1
weekend=0

if [ $pretest -eq 1 ]; then
        iotest=0
        seqresettest=0
        parreset_w_intv=1
        parreset_wo_intv=1
        parreset_wo_intv_4k_meta=0
        runtime="20s"
else
        iotest=1
        seqresettest=1
        parreset_w_intv=1
        parreset_wo_intv=1
        parreset_wo_intv_4k_meta=1
        if [ ${weekend} -eq 1 ]; then
                runtime="300s"
        else
                runtime="60s"
        fi
fi

typesplit=0                     # 0=Equal Split         1=Differential Split
acctype=1                       # 0=Sequential          1=Random(Default)
blocksize=0                     # -1=Random(Default)    0=Random by script              Others=figures
pattern=7                       # 0=Random      3=8bit_Incr     14=Zeor         100=Use LBA in Test Pattern
lbatype=3                       # 1=Normal      2=Extended      3=Timestamped(Default)
thread=256
poll=10                         # polling time for status checking
pract_rand=0            # select pract random (0:Random, 1:PRACT=1 only, 2:PRACT=0 only )
dualvf_mode=1           # 0:port1 vf continuously 1:port1 vf fixed
rst_intv_time=40        # reset interval time
fullwriteinit=1         # 0:Not completed       1:Completed

#enabled lun array for I/O testing
declare -a lunset
##      ns1           ns8             ns16            ns24            ns32  #
#lunset=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)
#      ns1           ns8             ns16            ns24            ns32  #
lunset=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1)
#lunset=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 1 1 1 1 0 0 1 1 0 0 0 0) #except 4K+64
#lunen : sorting enabled namespaces from lunset array
declare -a lunen
declare -a intlunen
intluncnt=0
declare -a iotype
#*********************************************************
#iotype[0] should be set "Write" because of DIF/DI
#*********************************************************
if [ $pretest -eq 1 ]; then
        iotype=("Compare")
else
        if [ ${weekend} -eq 0 ]; then
                iotype=("Compare" "R50W50" "Write")
        else
                iotype=("Compare" "R50W50" "Write" "Read" "R10W90" "R90W10")
        fi
fi

#enabled lun array for reset testing
declare -a resetlun
###      ns1           ns8             ns16            ns24            ns32  #
#resetlun=(1 0 1 0 1 1 1 1 0 0 1 1 1 1 0 0 1 1 1 1 0 0 1 1 1 1 0 0 1 1 1 1)
resetlun=(1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
#resetlun=(0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
declare -a resetlunen

#for logging
PID=
HOMEDIR="$( cd "$( dirname "$0" )" && pwd )"
TESTNAME=$(basename $0)
TESTSUITE="$2"
HOME=`pwd`
DAEMON=${HOMEDIR}/${TESTNAME}
PIDDIR=${HOMEDIR}
PIDFILE=${HOMEDIR}/pid
LOCKFILE=${HOMEDIR}/lock
LOGFILE=${DAEMON}.log
LUNDIR=`echo ${HOMEDIR} |awk -F'/tests'  '{ print $1 }'`

if [ $blocksize -eq 0 ]; then
        randflag=1
else
        randflag=0
fi

declare -a intrtype
declare -a cmbtype

declare -i bgname
for (( i=0; i<16; i++ ))
do
        bgname[i]=0
done
declare -i resetbg
for (( i=0; i<16; i++ ))
do
        resetbg[i]=0
done

cmb_rand=1
vf_cmb_on=0
sameoption=1

limitsize=8
numtarget=0
reset_intv=0
admin_on=1
mdts=32
maxvf=15
max_func=16
if [ ${numport} -eq 1 ]; then
        max_num_func=${max_func}
else
        max_num_func=`expr ${max_func} \/ 2`
fi

HAVESUBS=1

#***********************************************************************
#ns  1, lba_shift 12, meta_shift  0, extended  0, dps 0x00 aes key idx 0xff
#ns  2, lba_shift  9, meta_shift  0, extended  0, dps 0x00 aes key idx 0xff
#ns  3, lba_shift 12, meta_shift  0, extended  0, dps 0x00 aes key idx 0x00
#ns  4, lba_shift  9, meta_shift  0, extended  0, dps 0x00 aes key idx 0x01
#ns  5, lba_shift 12, meta_shift  3, extended  1, dps 0x00 aes key idx 0xff
#ns  6, lba_shift 12, meta_shift  3, extended  0, dps 0x00 aes key idx 0xff
#ns  7, lba_shift 12, meta_shift  6, extended  1, dps 0x00 aes key idx 0xff
#ns  8, lba_shift 12, meta_shift  6, extended  0, dps 0x00 aes key idx 0xff
#ns  9, lba_shift  9, meta_shift  3, extended  1, dps 0x00 aes key idx 0xff
#ns 10, lba_shift  9, meta_shift  3, extended  0, dps 0x00 aes key idx 0xff
#ns 11, lba_shift 12, meta_shift  3, extended  1, dps 0x00 aes key idx 0x02
#ns 12, lba_shift 12, meta_shift  3, extended  0, dps 0x00 aes key idx 0x03
#ns 13, lba_shift 12, meta_shift  6, extended  1, dps 0x00 aes key idx 0x04
#ns 14, lba_shift 12, meta_shift  6, extended  0, dps 0x00 aes key idx 0x05
#ns 15, lba_shift  9, meta_shift  3, extended  1, dps 0x00 aes key idx 0x06
#ns 16, lba_shift  9, meta_shift  3, extended  0, dps 0x00 aes key idx 0x07
#ns 17, lba_shift 12, meta_shift  3, extended  1, dps 0x09 aes key idx 0xff
#ns 18, lba_shift 12, meta_shift  3, extended  0, dps 0x09 aes key idx 0xff
#ns 19, lba_shift 12, meta_shift  6, extended  1, dps 0x09 aes key idx 0xff
#ns 20, lba_shift 12, meta_shift  6, extended  0, dps 0x09 aes key idx 0xff
#ns 21, lba_shift  9, meta_shift  3, extended  1, dps 0x09 aes key idx 0xff
#ns 22, lba_shift  9, meta_shift  3, extended  0, dps 0x09 aes key idx 0xff
#ns 23, lba_shift 12, meta_shift  3, extended  1, dps 0x09 aes key idx 0x02
#ns 24, lba_shift 12, meta_shift  3, extended  0, dps 0x09 aes key idx 0x03
#ns 25, lba_shift 12, meta_shift  6, extended  1, dps 0x09 aes key idx 0x04
#ns 26, lba_shift 12, meta_shift  6, extended  0, dps 0x09 aes key idx 0x05
#ns 27, lba_shift  9, meta_shift  3, extended  1, dps 0x09 aes key idx 0x06
#ns 28, lba_shift  9, meta_shift  3, extended  0, dps 0x09 aes key idx 0x07
#ns 29, lba_shift 12, meta_shift  6, extended  1, dps 0x01 aes key idx 0xff
#ns 30, lba_shift 12, meta_shift  6, extended  0, dps 0x01 aes key idx 0xff
#ns 31, lba_shift 12, meta_shift  6, extended  1, dps 0x01 aes key idx 0x04
#ns 32, lba_shift 12, meta_shift  6, extended  0, dps 0x01 aes key idx 0x05
#***********************************************************************

