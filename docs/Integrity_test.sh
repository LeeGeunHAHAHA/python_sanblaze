#!/usr/bin/env bash

HAVESUBS=0
INPUT=/workspace/Test_DataIntegrity/DataIntegrity_Input.sh
while (( ! HAVESUBS )); do
        source $INPUT
        if (( $? )); then echo "  INFO: `basename ${0}` Waiting for file ${INPUT}"
                sleep 1;
        fi
done

HAVESUBS=0
LIBRARY=/workspace/Test_DataIntegrity/DataIntegrity_Library.sh
while (( ! HAVESUBS )); do
        source $LIBRARY
        if (( $? )); then echo "  INFO: `basename ${0}` Waiting for file ${LIBRARY}"
                sleep 1;
        fi
done

#Initialize Test Options
Initialize

doLogEcho "Enable IO Type = ${iotype[@]}"
#Get MaxLBA of Target
GetMaxLba $port $target
doLogEcho "Maximum LBA = ${MAXLBA}"

#=================================
#      dataIntegrity Function
#=================================
#1 : startvf(Start VF)
#2 : endvf(End VF)
#3 : intvvf : interval of virtual furnction
#4 : inc0dec1vf : 0=increased interval, 1=decreased interval for VFs
#5 : startrt(start runtype)
#6 : endrt(end runtype)
#7 : intvrt(interval of runtype)
#8 : inc0dec1rt(0=increased interval, 1=decreased interval for runtype)
#==================================
#                       I/O Test
#==================================
#Check Enabled LUN values and count
SetDefault
echo Retry=0 >/iport0/port
EnabledLUN lunset[@]
intlunen=`cat lunenfile`
luncnt=`cat luncntfile`
lunen=($intlunen)
doLogEcho "Enable LUN(Namespace ID) = ${lunen[@]}"
doLogEcho "Enable LUN Count = ${luncnt}"
#Get Capacity and Blocksize of All LUNs
GetBlockSize $luncnt
#Set LBA Type for I/O Testing
SetLBATypes $pattern $lbatype
#Application Tag=Fixed value
apptag=a53c
cmb_rand=1              #1:Use Random CMB (Default=1)
vf_cmb_on=0             #1:Use VF CMB (Default=0)
sameoption=1    #1:Use Same CMB&Interrupt Type between functions (Default=1)
admin_on=1              #1:Use Admin Command(Identify) on BackGroud
if [ ${iotest} -eq 1 ]; then

        echo GeneralTimeout=3600000ms >/iport0/port
        echo ReadWriteTimeout=3600000ms >/iport0/port
        echo TaskMgmtTimeout=3600000ms >/iport0/port
        echo NoPathTimeout=3600000ms >/iport0/port
        GeneralTO=3600

        doLogEcho "+++++++++++++ IO Test Start ++++++++++++++"
        if [ ${pretest} -eq 1 ]; then
                dataIntegrity 16 16 1 1 2 2 1 1 0 0
        else
                dataIntegrity 16 0 8 1 2 2 1 1 0 0
        fi
        FinishTest 0 0
        doLogEcho "+++++++++++++ IO Test End ++++++++++++++"
fi
#==================================
#                       Reset Test
#==================================
SetDefault
echo Retry=20 >/iport0/port
runtime="0"
#Check Enabled LUN values and count
EnabledLUN resetlun[@]
intlunen=`cat lunenfile`
luncnt=`cat luncntfile`
lunen=($intlunen)
doLogEcho "Enable Reset LUN(Namespace ID) = ${lunen[@]}"
doLogEcho "Enable Reset LUN Count = ${luncnt}"
#Get Capacity and Blocksize of All LUNs
GetBlockSize $luncnt
#Set LBA Type for I/O Testing
SetLBATypes $pattern $lbatype
#FLR Test with I/O
iotype=("Compare")
cmb_rand=0
echo GeneralTimeout=20000ms >/iport0/port
echo ReadWriteTimeout=40000ms >/iport0/port
echo TaskMgmtTimeout=10000ms >/iport0/port
echo NoPathTimeout=60000ms >/iport0/port
rst_intv_time=60
GeneralTO=60
#=================================
#      resetIntegrity Function
#=================================
#1 : startvf(Start Number of VF)
#2 : endvf(End Number of VF)
#3 : intvvf : interval of virtual furnction
#4 : inc0dec1vf : 0=increased interval, 1=decreased interval for VFs
#5 : resettype (0=NVM Subsystem Reset | 1=Controller Reset | 2=PCI Functional Reset | 3=PCI Conventional Reset | 4=Fundamental Reset (via Quarch PERST# Glitch)
#6 : iteration of reset

if [ ${seqresettest} -eq 1 ]; then
        fixed_thread=32
        fixed_bs=32

        doLogEcho "+++++++++++++ Sequential FLR Test Start ++++++++++++++"
        SeqresetIntegrity 16 16 8 1 2 5
        FinishTest 0 0
        doLogEcho "+++++++++++++ Sequential FLR Test End ++++++++++++++"

#       doLogEcho "+++++++++++++ Sequential Hot Reset Test Start ++++++++++++++"
#       SeqresetIntegrity 0 0 8 1 3 10
#       FinishTest 0 0
#       SeqresetIntegrity 16 16 8 1 3 3
#       FinishTest 0 0
#       doLogEcho "+++++++++++++ Sequential Hot Reset Test End ++++++++++++++"
fi

echo GeneralTimeout=20000ms >/iport0/port
echo ReadWriteTimeout=40000ms >/iport0/port
echo TaskMgmtTimeout=10000ms >/iport0/port
echo NoPathTimeout=60000ms >/iport0/port
rst_intv_time=60
if [ ${parreset_w_intv} -eq 1 ]; then
        fixed_thread=8
        if [ ${numport} -eq 2 ]; then
                fixed_thread=1 #`expr $fixed_thread \/ 4`
        fi
        fixed_bs=32
        reset_intv=1
        reset_cycle=100
        if [ ${pretest} -eq 1 ]; then
                reset_cycle=10
        else
                reset_cycle=100
        fi
        doLogEcho "+++++++++++++ Parallel Reset Test /w interval time Start ++++++++++++++"
        if [ ${numport} -eq 1 ]; then
                resetIntegrity 16 16 2 0 2 100
        else
                resetIntegrity 8 8 2 0 2 100
        fi
        FinishTest 0 0
        doLogEcho "+++++++++++++ Parallel Reset Test /w interval time  End ++++++++++++++"
fi

if [ ${parreset_wo_intv} -eq 1 ]; then
        fixed_thread=8
        if [ ${numport} -eq 2 ]; then
                fixed_thread=1 #`expr $fixed_thread \/ 4`
        fi
        fixed_bs=32
        reset_intv=0
        reset_cycle=1000
        if [ ${pretest} -eq 1 ]; then
                reset_cycle=100
        else
                reset_cycle=1000
        fi
        doLogEcho "+++++++++++++ Parallel Reset Test /wo interval time Start ++++++++++++++"
        if [ ${numport} -eq 1 ]; then
                resetIntegrity 16 16 2 0 2 1000
        else
                resetIntegrity 8 8 2 0 2 1000
        fi
        FinishTest 0 0
        doLogEcho "+++++++++++++ Parallel Reset Test /wo interval time End ++++++++++++++"
fi

if [ ${parreset_wo_intv_4k_meta} -eq 1 ]; then
        fixed_thread=8
        if [ ${numport} -eq 2 ]; then
                fixed_thread=1 #`expr $fixed_thread \/ 4`
        fi
        fixed_bs=32
        reset_intv=0

        resetlun=(1 0 1 0 1 1 1 1 0 0 1 1 1 1 0 0 1 1 1 1 0 0 1 1 1 1 0 0 1 1 1 1)
        #Check Enabled LUN values and count
        EnabledLUN resetlun[@]
        intlunen=`cat lunenfile`
        luncnt=`cat luncntfile`
        lunen=($intlunen)
        doLogEcho "Enable Reset LUN(Namespace ID) = ${lunen[@]}"
        doLogEcho "Enable Reset LUN Count = ${luncnt}"
        #Get Capacity and Blocksize of All LUNs
        GetBlockSize $luncnt
        #Set LBA Type for I/O Testing
        SetLBATypes $pattern $lbatype

        doLogEcho "+++++++++++++ Parallel Reset Test /wo interval time Start(4KB+meta) ++++++++++++++"
        if [ ${numport} -eq 1 ]; then
                resetIntegrity 16 16 2 0 2 1000
        else
                resetIntegrity 8 8 2 0 2 1000
        fi
        FinishTest 0 0
        doLogEcho "+++++++++++++ Parallel Reset Test /wo interval time End(4KB+meta) ++++++++++++++"
fi

FinishTest 1 0
