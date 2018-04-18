
#!/bin/bash

# This file contains common code subroutines used by multiple scripts
doLog() {
    local d=`date +"%a %b %d %H:%M:%S %Y"`
    echo ${d} "$@" >> ${LOGFILE}
}
doEcho() {
    echo "$@"
}
# Log and echo
doLogEcho(){
        doLog "$@"
        doEcho "$@"
}

dataIntegrity() {

        local startvf=$1                #1 : startvf(start VF)
        local endvf=$2                  #2 : endvf(end VF)
        local intvvf=$3                 #3 : intvvf : interval of virtual furnction
        local inc0dec1vf=$4             #4 : inc0dec1vf : 0=increased interval, 1=decreased interval for VFs
        local startrt=$5                #5 : startrt(start runtype)
        local endrt=$6                  #6 : endrt(end runtype)
        local intvrt=$7                 #7 : intvrt : interval of runtype
        local inc0dec1rt=$8             #8 : inc0dec1rt : 0=increased interval, 1=decreased interval for runtype

        #   dataIntegrity 16 16 1 1 2 2 1 1 0 0

        local testname
        declare -a testname

        #set varialbes which are used in for statement according to input argument
        if [ $inc0dec1vf -eq 0 ]; then
                vfintvtype="nnumvf+"
                vflimittype="nnumvf<"
        else
                vfintvtype="nnumvf-"
                vflimittype="nnumvf>"
        fi
        if [ $inc0dec1rt -eq 0 ]; then
                rtintvtype="runtype+"
                rtlimittype="runtype<"
        else
                rtintvtype="runtype-"
                rtlimittype="runtype>"
        fi

        #Starting I/O Test
        for (( nnumvf=$startvf; $vflimittype=$endvf; $vfintvtype=$intvvf ))
        do
                if [ $nnumvf -ne 0 ]; then
                        numvf=`expr $nnumvf \- 1`
                else
                        numvf=$nnumvf
                fi

                for (( runtype=$startrt; $rtlimittype=$endrt; $rtintvtype=$intvrt ))
                do
                        doLogEcho "============== Run Type = "${runtype}" ============== "

                        #set run type(0, 1, 2)
                        # Run Type
                        # 0 : Running I/O each Namespaces of each Functions
                        # 1 : Running I/O each Namespaces of all Functions
                        # 2 : Running I/O all Namespaces of all Functions
                        SetSimultaneousNS_VF $runtype
                        for (( tp=0; tp<${#iotype[@]}; tp++ ))
                        do
                                vfEnable $numvf $port $target $target2
                                doLogEcho "============== IO Type = "${iotype[tp]}" ============== "
                                echo WriteEnabled=1 >/iport${port}/target${target}
                                if [ ${fullwriteinit} -eq 0 ]; then
                                        FullWriteForDIFDIX ${lunen[@]}
                                fi
                                doLogEcho "Complete Seq. Full Write"
                                divide=`expr ${#lunset[@]} \* ${simvf}`
                                endloop=`expr ${numport} \* ${luncnt} \* \( ${numvf} \+ 1 \)`
                                numtarget=`expr ${numport} \* \( ${numvf} \+ 1 \)`
                                doLogEcho "============== Set Options for each target  ============== "
                                if [ $sameoption -eq 1 ]; then
                                        sft=`expr ${RANDOM} \% 2 \+ 1`  #VF can't use INT       #VF can't use INTxx
                                fi
                                for (( looptarget=0; looptarget<${numtarget}; looptarget++ ))
                                do
                                        SelectTarget $numvf $looptarget $numtarget
                                        RandomINTRType $port $queuetarget
                                        intrtype[$looptarget]=${intr_values} #this value is used for test-naming
                                        if [ ${queuetarget} -eq ${target} ] || [ ${queuetarget} -eq ${target2} ]; then
                                                doLogEcho "CMB(cmbtype=${cmbtype[looptarget]} is already set at VF enable"
                                        else
                                                if [ ${vf_cmb_on} -eq 0 ]; then
                                                        cmbtype[$looptarget]=0
                                                else
                                                        RandomCMBType $port $queuetarget
                                                        cmbtype[$looptarget]=cmben
                                                fi
                                                doLogEcho "Restart target${queuetarget} in order to change CMB and Interrupt Type"
                                                echo restart=${queuetarget} > /proc/vlun/nvme
                                        fi

                                        if [ ${admin_on} -eq 1 ]; then
                                                IdentifyController $queuetarget 10 &
                                                bgname[looptarget]=$!   #background job name. It will be used when I/O test is completed and restart other I/O testings
                                                doLogEcho "Admin CMD Background Job's PID=${bgname[looptarget]}"
                                        fi
                                done
                                sleep 5

                                loopcnt=0
                                looptarget=0
                                lun=0
                                doLogEcho "The number of Endloop = $endloop"

                                for (( loop=0; loop<${endloop}; loop++ ))
                                do
                                        doLogEcho "Current Loop Count = $loop"
                                        doLogEcho "============== Running I/O ============== "
                                        SelectTarget $numvf $looptarget $numtarget
                                        DefineTestArea $divide $queuetarget ${looptarget} ${lun}
                                        SetRunTime $simvf $simns $runtime $runtimeout
                                        testname[${loopcnt}]=${iotype[tp]}_target${queuetarget}_lun${lunen[$lun]}_cmb${cmbtype[$looptarget]}_intr${intrtype[$looptarget]}_runtype${runtype}_numvf${numvf}
                                        doLogEcho "Test Name = ${testname[$loopcnt]}"
                                        if [ ${randflag} -eq 1 ]; then
                                                if [ ${limitsize} -lt ${mdts} ]; then
                                                        blocksize=`expr ${RANDOM} \% ${limitsize} \+ 1`
                                                else
                                                        blocksize=`expr ${RANDOM} \% ${mdts} \+ 1`
                                                fi
                                        fi
                                        acctype=`expr ${RANDOM} \% 2`
                                        if [ $acctype -eq 0 ]; then
                                                accsym="Sequential"
                                        else
                                                accsym="Random"
                                        fi
                                        doLogEcho "Write Enable to target${queuetarget}"
                                        echo WriteEnabled=1 >/iport${port}/target${queuetarget}
                                        SetE2E ${lunen[lun]} ${queuetarget}
                                        echo ${testname[${loopcnt}]},${thread},${blocksize},${runtimeout},${acctype},0,0,${lbatype},-1,60,0,1,1,0,1:1,1:1,0,-0 > /iport$port/target${queuetarget}lun${lunen[$lun]}
                                        doLogEcho "Port=${port}, Target=${queuetarget}, NS=${lunen[$lun]}, #Test_Func=$simvf, #Test_NS=$simns, AccType=${accsym}, Blocksize=${blocksize}, Runtime=${runtimeout} "
                                        if [ ${runtype} -eq 0 ]; then
                                                statuscheck testname[@] $loopcnt $poll
                                                loopcnt=0
                                        elif [ ${runtype} -eq 1 ] && [ `expr ${loop} \% ${simvf}` -eq `expr ${simvf} \- 1` ]; then
                                                statuscheck testname[@] $loopcnt $poll
                                                loopcnt=0
                                        elif [ ${runtype} -eq 2 ] && [ ${loop} -eq `expr $endloop \- 1` ]; then
                                                statuscheck testname[@] $loopcnt $poll
                                                loopcnt=0
                                        else
                                                loopcnt=`expr $loopcnt \+ 1`
                                        fi

                                        if [ $looptarget -eq `expr $simvf \- 1` ]; then
                                                if [ $lun -eq `expr $luncnt \- 1` ]; then
                                                        doLogEcho "lun$lun == luncnt`expr $luncnt \- 1`"
                                                        lun=0
                                                else
                                                        let "lun+=1"
                                                        looptarget=0
                                                fi
                                        else
                                                looptarget=`expr $looptarget \+ 1`
                                        fi

                                done #target * lun
                                doLogEcho "============== Clear BackGound Job for each targets  ============== "
                                for (( looptarget=0; looptarget<${numtarget}; looptarget++ ))
                                do
                                        if [ ${bgname[looptarget]} -ne 0 ]; then
                                                doLogEcho "Kill BackGround Job(PID=${bgname[looptarget]})"
                                                kill -9 ${bgname[looptarget]} 2 >/dev/null
                                        fi
                                done
                        done #iotype
                done #runtype

        done #numvf

}

Initialize() {

        #Stop and Clear the previous testing for PF0 and PF1
        echo StopTests > /iport$port/target$target
        echo ClearTests > /iport$port/target$target
        if [ $numport -eq 2 ]; then
                echo StopTests > /iport$port/target$target2
                echo ClearTests > /iport$port/target$target2
        fi

        local vf=0
        for (( vf=0; vf<30; vf++ ))
        do
                echo StopTests > /iport$port/target$vf
                echo ClearTests > /iport$port/target$vf
        done

        #It doesn't use Recovery(Abort and Controller reset)
        echo TimeoutErrorRecovery=0 > /iport$port/port
        echo TestLimits=0,0,0 >/iport$port/port

        #Change Admin Command Timeout value
        echo 20000 > /sys/module/nvme/parameters/admin_timeout
        echo 30000 > /sys/module/nvme/parameters/abort_timeout
}

vfEnable() {

        numvf=$1
        port=$2
        target=$3
        target2=$4

    doLogEcho "============== VF Enable ============== "

        #initialize number of VF becuase of stability
        doLogEcho "Initialize Number of VF = 0(Port0)"
        echo NumVFs=0 >/iport$port/target$target
        sleep 3
        if [ ${numport} -eq 2 ]; then
                doLogEcho "Initialize Number of VF = 0(Port1)"
                echo NumVFs=0 >/iport$port/target$target2
        fi

        #set CMB value for PF because PF reset should be issued in only VF=0 status
        #180222 : Sanblaze doesn't yet fix this issue.
    doLogEcho "============== Set CMB for PF ============== "
        for (( i=0; i<$numport; i++ ))
        do
                if [ $i -eq 0 ]; then
                        looptarget=`expr $numport \* $numvf`
                else
                        looptarget=`expr $numport \* \( $numvf \+ 1 \) \- 1`
                fi

                #set cmb values from 0(CMBoff) to 3(SQ/CQ on), 2=(SQ only)
                if [ $cmb_rand -eq 1 ]; then
                        cmb=`expr ${RANDOM} \% 3`
                else
                        cmb=0
                fi
                if [ $i -eq 0 ]; then    #Port0
                        RandomCMBType $port $target
                        echo restart=${target} > /proc/vlun/nvme
                else                                    #Port1
                        RandomCMBType $port $target2
                        echo restart=${target2} > /proc/vlun/nvme
                fi
                #this values is used for test naming
                cmbtype[$looptarget]=$cmben
        done

        sleep 10

        #set number of VF
    doLogEcho "Number of VF = ${numvf}"
    doLogEcho "VF Enalbe of target${target}(Port0)"
    echo NumVFs=${numvf} >/iport$port/target$target                     #for Port0

        sleep 10

        if [ ${numport} -eq 2 ]; then
        doLogEcho "VF Enalbe of target${target2}(Port1) for Dual Port"
        echo NumVFs=${numvf} >/iport$port/target$target2        #for Port1
    fi

}

GetTestStatus()
{
        local name=$1   #1 : testname

        #find a testname to check status in /iport0/tests/
        if ls /iport$port/tests/ | grep ${name}$
        then
                if grep -q "Failed" /iport$port/tests/$name
                then
                        teststatus=-1
                elif grep -q "Passed" /iport$port/tests/$name
                then
                        teststatus=1
                else
                        teststatus=0
                fi
        else
                doLogEcho "Test doesn't exist! It likely failed to start. Check /var/log/messages for details."
                teststatus=-1
        fi
}

statuscheck() {

        local name
        declare -a name=("${!1}")       #1 : group of testname
        endcnt=`expr ${2} \+ 1`         #2 : the number of test group
        local loop=0
        local polltime=${3}                     #3 : polling time to check status

    doLogEcho "============== Check Status for I/O ============== "

        for (( loop=0; loop<${endcnt}; loop++ ))
        do
                doLogEcho "Test name = ${name[loop]}"
                GetTestStatus ${name[loop]}

                #check status until status makes either Pass or Fail
                while [ $teststatus -eq 0 ]     #Running
                do
                        #doLogEcho "Test is still running. Sleeping $poll before polling again"
                        if [ ${loop} -eq 0 ] || [ $teststatus -eq 0 ]
                        then
                                sleep $polltime
                        fi
                        GetTestStatus ${name[$loop]}

#                       if [ $loop -eq `expr ${endcnt} \- 1` ]; then
#                               loop=0
#                       else
#                               loop=`expr loop \+ 1`
#                       fi
                done

                if [ $teststatus -eq 1 ]; then
                        doLogEcho "PASS : Test is passed"
                elif [ $teststatus -eq -1 ]; then
                        doLogEcho "FAILED : Test is failed, TESTNAME : ${name[loop]}"
                        FinishTest 1 1
                else
                        doLogEcho "ERROR: Test is failed, TESTNAME : ${name[loop]}"
                fi

        done

}

EnabledLUN() {

        `rm -rf $lunenfile`
        `rm -rf $luncntfile`

        declare -a lunset=("${!1}")             #1 : lunset
        # extract enabled namespaces
        lunloop=${#lunset[@]}
        local result=0

        local myluncnt=0
        local -a mylunen

        #sort enabled lun(namespace)
        for (( i=0; i<${lunloop}; i++ ))
        do
                #if value is zero, a namespace is enabled
                if [ "${lunset[i]}" -eq "1" ]; then
                        result=`expr $i \+ 1`
                        mylunen[myluncnt]="${result}"
                        #count the number of enabled namespace
                        myluncnt=`expr ${myluncnt} \+ 1`
                fi
        done

        #return array of enabled lun(namespace) and the number of enabled lun
        echo ${mylunen[@]} > "lunenfile"
        echo ${myluncnt} > "luncntfile"

}

GetMaxLba() {
        # get maxlba
        maxblock="-1"
        result=`grep blocks /iport${port}/target${target}lun1`
        re="([0-9]*) blocks"
        if [[ $result =~ $re ]]; then
        maxblock=${BASH_REMATCH[1]}
        fi
        MAXLBA=$maxblock
}

GetBlockSize() {

        local luncnt=$1

        for (( i=0; i<${luncnt}; i++ ))
    do
        result=`grep blocks /iport${port}/target${target}lun${lunen[i]}`
        re="([0-9]*) blocks"
        if [[ $result =~ $re ]]; then
            nscap[i]=${BASH_REMATCH[1]}
        fi
        doLog "${lunen[i]}'s capacity = ${nscap[i]}"

        result=`grep BlockSize= /iport${port}/target${target}lun${lunen[i]}`
        re="BlockSize=([0-9]*)"
        if [[ $result =~ $re ]]; then
            nsblocksize[i]=${BASH_REMATCH[1]}
        fi
        doLogEcho "${lunen[i]}'s blocksize = ${nsblocksize[i]}"
    done


}

SetLBATypes() {

        local pattern=$1
        local lbatype=$2

    if [ ${pattern} -eq 100 ]; then
        doLogEcho "============== Using Timestamped Pattern ============== "
        echo LBAInPatterns=${lbatype} > /iport${port}/port
    fi

}

SetRunTime() {

        local simvf=$1
        local simns=$2
        local int_runtime="$3"

        int_runtime=${int_runtime%s}
        #determine runtime considering the number of namespaces which are running simultaneously
        int_runtime=`expr ${int_runtime} \* ${simns}`
        runtimeout="${int_runtime}""s"
        echo "$runtimeout"

}

RandomCMBType() {

        local port=$1
        local localtarget=$2

        #If sameoption is enables, all function should be set same CMB Option
        if [ $sameoption -eq 0 ]; then
                cmb=`expr ${RANDOM} \% 3`
        fi

        if [ ${cmb} -eq 0 ]; then
                cmben=0                                         #CMB disable
        elif [ ${cmb} -eq 1 ]; then
                cmben=1                                         #CMB SQ enable
        else
                cmben=3                                         #CMB SQ/CQ enable
        fi

        echo UseCMB=${cmben} > /iport${port}/target${localtarget}
        #echo restart=${localtarget} > /proc/vlun/nvme
        doLogEcho "============== Use CMB=${cmben} of target${localtarget} ============== "

}

RandomINTRType() {

        local port=$1
        local localtarget=$2

        #If sameoption is enables, all function should be set same Interrupt Option
        if [ $sameoption -eq 0 ]; then
                if [ $localtarget -ne $target ] && [ $localtarget -ne $target2 ]; then
                        sft=`expr ${RANDOM} \% 2 \+ 1`  #VF can't use INT       #VF can't use INTxx
                else
                        sft=`expr ${RANDOM} \% 3`
                fi
        fi

        #Interrrupt type
        #sft=0 : Legacy (intr_values=1)
        #sft=1 : MSI    (intr_values=3)
        #sft=2 : MSI-X  (intr_values=7)
        let "intr_values=1 << (${sft}+1)"
        intr_values=`expr ${intr_values} \- 1`

        echo InterruptTypes=${intr_values} > /iport${port}/target${localtarget}
        doLogEcho "============== InterruptType=${intr_values} of target${localtarget} ============== "

}

DefineTestArea() {

        #local loopcnt=$1
        local divide=$1                 #1 : Test ranges which are divided according to both the number of VFs          and the number of lun(namespace)
        local localtarget=$2    #2 : Target number
        local i=$3                              #3 : loop target
        local j=$4                              #4 : loop lun

        #limit size for each test sessions
        local int_limitsize=`expr ${MAXLBA} \/ ${divide}`
        doLogEcho "Debugging : Maxlba=${MAXLBA}, divide=${divide}"
        #limit size per namespace
        local size_perns=`expr ${MAXLBA} \/ ${#lunset[@]}`
        limitsize=${int_limitsize}

        #start point for each test sessions
        local position=`expr ${size_perns} \* \( ${lunen[j]} \- 1 \) \+ \( ${int_limitsize} \* ${i} \)`
        doLogEcho "size_perns=$size_perns, position=$position, lun=${lunen[j]}"

        doLogEcho "int_limitsize=${int_limitsize}, positon=${position}"

        doLogEcho "NS${lunen[j]}'s blocksize = ${nsblocksize[j]}"

        #set limitsize and position according to blocksize of namespaces
        if [ ${nsblocksize[j]} -le 520 ] && [ ${nsblocksize[j]} -ge 512 ]; then #blocksize=512 or 512+meta
                doLogEcho "Blocksize = 512 or 512 + meta"
                mdts=255
                #multiple 8 to limitsize and position if blocksize is 512 or 512+meta
                echo TestLimits=`expr ${int_limitsize} \* 8`,`expr ${position} \* 8`,0 >/iport$port/port
                iosize=`expr ${nsblocksize[j]} \* ${int_limitsize} \* 8 \/ 1024`
                ioposition=`expr ${nsblocksize[j]} \* ${position} \* 8 \/ 1024`
                doLogEcho "Target=${localtarget}, LUN=`expr ${j} \+ 1`, Test Limit Size=`expr ${int_limitsize} \* 8`(${iosize}KB), Position=`expr ${position} \* 8`(${ioposition}KB), Thread=${thread}"
        else                                                                                                                                    #blocksize=4K or 4K+meta
                mdts=31
                echo TestLimits=${int_limitsize},${position},0 >/iport$port/port
                iosize=`expr ${nsblocksize[j]} \* ${int_limitsize} \/ 1024`
                ioposition=`expr ${nsblocksize[j]} \* ${position} \/ 1024`
                doLogEcho "Target=${localtarget}, LUN=`expr ${j} \+ 1`, Test Limit Size=`expr ${int_limitsize}`(${iosize}KB), Position=`expr ${position}`(${ioposition}KB), Thread=${thread}"
        fi



}

SelectTarget() {

        local numvf=$1
        local looptarget=$2
        local endtarget=$3

        if [ ${numvf} -eq 0 ]; then                                     # PF Only(#VF=0)
                if [ ${numport} -eq 1 ]; then
                        queuetarget=${target}
                else
                        if [ ${looptarget} -eq 0 ]; then
                                queuetarget=${target}
                        else
                                queuetarget=${target2}
                        fi
                fi
        else                                                                            # #VF>0
                if [ ${numport} -eq 1 ]; then
                if [ `expr ${looptarget} \% \( ${endtarget} \)` == `expr ${endtarget} \- 1` ]; then
                                queuetarget=${target}                                                                           #PF0 in single port
                        else
                                queuetarget=`expr ${looptarget} \% \( ${endtarget} \)`          #VFs in single port
                        fi
                else
                        if [ `expr ${looptarget} \% \( ${endtarget} \)` == `expr ${endtarget} \- 2` ]; then
                                queuetarget=${target}                                                                           #PF0 in dual port
                        elif [ `expr ${looptarget} \% \( ${endtarget} \)` == `expr ${endtarget} \- 1` ]; then
                                queuetarget=${target2}                                                                          #PF1 in dual port
                        else
                                if [ ${dualvf_mode} -eq 0 ]; then
                                        queuetarget=`expr ${looptarget} \% \( ${endtarget} \)`          #VFs in dual port
                                else
                                        if [ ${looptarget} -lt ${numvf} ]; then
                                                queuetarget=`expr \( ${looptarget} \% ${numvf} \)`      #VFs in dual port
                                        else
                                                queuetarget=`expr \( ${looptarget} \% ${numvf} \) \+ ${maxvf}`  #VFs in dual port
                                        fi
                                fi
                        fi
                fi
        fi

        doLogEcho "Current Target = $queuetarget"

}

SetE2E() {

        local lunnum=$1
        local localtarget=$2

        #Select PRACT either 0 or 1(insert/strip) for IO testing
        local pract=0
        if [ ${pract_rand} -eq 0 ]; then
                if [ $lunnum -ne 20 ] && [ $lunnum -ne 26 ] && [ $lunnum -ne 30 ] && [ $lunnum -ne 32 ]; then #18.02.28 host issue. 64B_meta+separate+PRACT=1->fatal error
                        pract=`expr ${RANDOM} \% 2`
                else
                        pract=0
                fi
        elif [ ${pract_rand} -eq 1 ]; then
                pract=1
        else
                pract=0
        fi

        if [ ${lunnum} -ge 17 ]; then
                doLogEcho "PRACT=${pract} in target${localtarget}lun${lunnum}"
                if [ ${pract} -eq 0 ]; then
                        echo NoT10DIF=2 >/iport${port}/port     #T10 DIF Enable SW
                else
                        echo NoT10DIF=0 >/iport${port}/port     #T10 DIF Enable HW(Default)
                fi
                echo PRCHK=7,1 >/iport${port}/port      #PRCHK 7
                echo AppTag=${apptag},ffff >/iport${port}/port
                doLogEcho "NoT10DIF=2/ PRCHK=7,1/ AppTag=a500,ffff"
        else
                echo NoT10DIF=0 >/iport${port}/port     #T10 DIF(Default)
                echo PRCHK=0,0 >/iport${port}/port      #PRCHK 0
                echo AppTag=0,ffff >/iport${port}/port
                doLogEcho "NoT10DIF=0/ PRCHK=0,0/ AppTag=0,ffff"
        fi

}

FullWriteForDIFDIX() {

        local loop
        local iotype="Write"

        local encnt=${#lunen[@]}

        declare -a test_name

        #area per namespace
        local size_perns=`expr ${MAXLBA} \/ ${#lunset[@]}`
        doLogEcho "size per ns = ${size_perns}"

        for (( loop=0; loop<$encnt; loop++ ))
        do

                DefineTestArea ${#lunset[@]} $target 0 $loop

                test_name[loop]=${iotype}_target${target}_lun${lunen[loop]}
                #echo "${test_name[loop]}"
                SetE2E ${lunen[loop]} ${target}
                echo ${test_name[loop]},1,128kb,1024mb,0,0,0,0,0,0,0,1,1,0,1:1,1:1,0,-0 >/iport$port/target${target}lun${lunen[loop]}
        done

        statuscheck test_name[@] `expr $encnt \- 1` 3

        fullwriteinit=1         # 0:Not completed       1:Completed
}

FullReadForDIFDIX() {

        local loop
        local iotype="Read"

        local encnt=${#lunen[@]}

        declare -a test_name

        #area per namespace
        local size_perns=`expr ${MAXLBA} \/ ${#lunset[@]}`
        doLogEcho "size per ns = ${size_perns}"

        for (( loop=0; loop<$encnt; loop++ ))
        do

                DefineTestArea ${#lunset[@]} $target 0 $loop

                test_name[loop]=${iotype}_target${target}_lun${lunen[loop]}
                #echo "${test_name[loop]}"
                SetE2E ${lunen[loop]} ${target}
                echo ${test_name[loop]},1,128kb,1024mb,0,0,0,0,0,0,0,1,1,0,1:1,1:1,0,-0 >/iport$port/target${target}lun${lunen[loop]}
        done

        statuscheck test_name[@] `expr $encnt \- 1` 3

}

#PollNumVFs() {
#
#       local lastvf=`expr $1 \- 1`
#
#       vffind="0"
#       while [ "$vffind" != " " ]
#       do
#               vffind=`ls /iport${port}/target${target}`
#               if [ "$vffind" != " " ]; then
#                       doLogEcho "Wait for disable target${target}"
#                       sleep 10
#               fi
#       done
#
#       vffind="0"
#       while [ "$vffind" == "0" ]
#       do
#               vffind=`ls /iport${port}/target${lastvf}`
#               if [ "$vffind" == " " ]; then
#                       doLogEcho "Wait for ready last ${1}VF"
#                       sleep 10
#               fi
#       done
#}

IdentifyController() {

        local local_target=$1   #1 : target number
        local sleep_time=$2             #2 : interval time between Identify Controllers Commands in a function
        local i #return value for identify controller

        while [ 1 ]
        do
            io /iport${port}/target${local_target} IdentifyCntroller -q -timeout ${GeneralTO}
        i=$?
            if (( $i )); then
                        doLogEcho " ERROR(P${port}:T${local_target}), return value=${i}: IdentifyController command failed, unable to verify the size of the returned data structure and to determine the number of valid namespaces"
                else
                        doLog "DETAIL(P${port}:T${local_target}): IdentifyController command passed, therefore we can infer an entry was posted to the Admin Completion Queue.  Also note that the VirtuaLUN is incapable of verifying memory buffers     as it doesn't have analyzer capabilities."
                fi

                        #2 : interval time between Identify Controllers Commands in a function
                sleep ${sleep_time}
        done
}

ResetTest() {

        local local_testname
        declare -a local_testname=("${!1}")     #1 : group of test name
        local local_target=$2                           #2 : target number
        local local_resettype=$3                        #3 : resettype (0=NVM Subsystem Reset | 1=Controller Reset | 2=PCI Functional Reset | 3=PCI Conventional Reset | 4=Fundamental Reset (via Quarch PERST# Glitch)
        local local_loop=$4                                     #4 : the number of reset loop
        local local_runtime=$5                          #5 : I/O running time between resets
        local bg_on=$6                                          #6 : backgroud on/off for reset testing

        local reset_type
        local intv_time

        doLogEcho "Test List = ${local_testname[@]}"
        doLogEcho "Start Reset Test in target${local_target}"
        if [ $bg_on -eq 1 ]; then
                doLogEcho "Reset Iteration Number = ${local_loop}"
                sleep 10
        fi

#       if [ $numvf -eq 0 ] || ([ "${local_target}" != "${target}" ] && [ "${local_target}" != "${target2}" ])
#       then

                for (( i=0; i<${local_loop}; i++ ))
                do
                        sleep ${local_runtime}

                        if [ $bg_on -eq 1 ] && [ $reset_intv -eq 1 ]; then
                                intv_time=`expr ${RANDOM} \% 10`
                                sleep ${intv_time}
                        fi

                        #statuscheck local_testname[@] ${#local_lun[@]} 10

                        GetTestStatus ${local_testname[0]}

            if [ ${teststatus} -eq -1 ]; then
                doLogEcho "Test status is Failed in ${local_testname[0]}"
                                FinishTest 1 1
            elif [ ${teststatus} -eq 1 ]; then
                doLogEcho "Test status is Passed. This is unexpected in ${local_testname[0]}"
                                FinishTest 1 0
            else
                doLogEcho "Test is still running"
            fi

                        # If Reset Type is random(local_resettype==100)
                        if [ $local_resettype -eq 100 ]; then
                                reset_type=`expr ${RANDOM} \% 5`
                        else
                                reset_type=${local_resettype}
                        fi

                        if [ $bg_on -eq 1 ]; then
                                doLogEcho "Reset Iteration Count of Target${local_target} = ${i}"
                        fi
                        if [ ${reset_type} -eq 0 ]; then
                                doLogEcho "Injecting NVMe Subsystem Reset on Controller Target${local_target}"
                                echo reset_nvm=${local_target} > /proc/vlun/nvme
                        elif [ ${reset_type} -eq 1 ]; then
                                doLogEcho "Injecting Controller Reset on Controller Target${local_target}"
                                echo reset_ctrl=${local_target} > /proc/vlun/nvme
                        elif [ ${reset_type} -eq 2 ]; then
                                doLogEcho "Injecting PCI Functional Reset on Controller target${local_target}"
                                echo reset_pci_func=${local_target} > /proc/vlun/nvme
                        elif [ ${reset_type} -eq 3 ]; then
                                doLogEcho "Injecting PCI Conventional Reset on Controller target${local_target}"
                                echo reset_pci_conv=${local_target} > /proc/vlun/nvme
                        else
                                doLogEcho "Glitching PERST# on Controller target${local_target}"
                                quarchGlitch
                        fi

                done

#       fi

        if [ $bg_on -eq 1 ]; then

                #doLogEcho "Wait 120secs"
                #sleep 120

                doLogEcho "Stop test for target${local_target} after completing Reset Test"
                echo StopTests>/iport$port/target$local_target
                exit 0
        fi

}

RecoveryTarget() {

        local looptarget=$1
        local resettype=$2

        doLogEcho "Recovery Target=${looptarget}, Reset Type=${resettype}"

        if [ ${resettype} -eq 0 ]; then
                doLogEcho "Injecting NVMe Subsystem Reseti on Controller Target${looptarget}"
                echo reset_nvm=${looptarget} > /proc/vlun/nvme
        elif [ ${resettype} -eq 1 ]; then
                doLogEcho "Injecting Controller Reset on Controller Target${looptarget}"
                echo reset_ctrl=${looptarget} > /proc/vlun/nvme
        elif [ ${resettype} -eq 2 ]; then
                doLogEcho "Injecting PCI Functional Reset on Controller target${looptarget}"
                echo reset_pci_func=${looptarget} > /proc/vlun/nvme
        elif [ ${resettype} -eq 3 ]; then
                doLogEcho "Injecting PCI Conventional Reset on Controller target${looptarget}"
                echo reset_pci_conv=${looptarget} > /proc/vlun/nvme
        else
                doLogEcho "Glitching PERST# on Controller target${looptarget}"
                quarchGlitch
        fi

}

quarchGlitch() {

        doLogEcho "Not Prepare"
}

SetDefault() {

        echo InterruptTypes=7 > /iport${port}/target${target}
        echo UseCMB=0 > /iport${port}/target${target}
        echo restart=${target} > /proc/vlun/nvme

        if [ $numport -eq 2 ]; then
                echo InterruptTypes=7 > /iport${port}/target${target2}
                echo UseCMB=0 > /iport${port}/target${target2}
                echo restart=${target2} > /proc/vlun/nvme
        fi

        echo TestLimits=0,0,0 >/iport$port/port
        echo NoT10DIF=0 >/iport${port}/port     #T10 DIF(Default)
        echo PRCHK=0,0 >/iport${port}/port      #PRCHK 0
        echo AppTag=0,ffff >/iport${port}/port

        echo GeneralTimeout=15000ms >/iport0/port
        echo ReadWriteTimeout=20000ms >/iport0/port
        echo TaskMgmtTimeout=10000ms >/iport0/port
        echo NoPathTimeout=60000ms >/iport0/port
        GeneralTO=15

}

KillBGJob() {

        local i

        for (( i=0; i<${numtarget}; i++ ))
        do
                SelectTarget $numvf $i $numtarget
                doLogEcho "Stop test for target${queuetarget} from Kill BG Job"
            echo StopTests>/iport$port/target${queuetarget}

                if [ ${bgname[i]} -ne 0 ]; then
                        doLogEcho "Ctrl+C : Kill Admin BackGround Job(PID=${bgname[i]})"
                        kill -9 ${bgname[i]} 2 >/dev/null
                fi
                if [ ${resetbg[i]} -ne 0 ]; then
                        doLogEcho "Ctrl+C : Kill Reset BackGround Job(PID=${resetbg[i]})"
                        kill -9 ${resetbg[i]} 2 >/dev/null

                        RecoveryTarget $queuetarget 2

                fi
        done

        exit 0

}
trap KillBGJob SIGINT

FinishTest() {

        local completed=$1
        local failed=$1

        local i

        for (( i=0; i<${numtarget}; i++ ))
        do
                SelectTarget $numvf $i $numtarget
                doLogEcho "Stop test for target${queuetarget} from completed test"
            echo StopTests>/iport$port/target${queuetarget}

                if [ ${bgname[i]} -ne 0 ]; then
                        doLogEcho "Kill Admin BackGround Job(PID=${bgname[i]})"
                        kill -9 ${bgname[i]} 2 >/dev/null
                        bgname[i]=0
                fi
                if [ ${resetbg[i]} -ne 0 ]; then
                        doLogEcho "Kill Reset BackGround Job(PID=${resetbg[i]})"
                        kill -9 ${resetbg[i]} 2 >/dev/null
                        resetbg[i]=0

                        if [ ${failed} -eq 0 ]; then
                                RecoveryTarget $i 2
                        fi
                fi
        done

        if [ $completed -eq 1 ]; then
                doLogEcho "Finish All Testing"
                exit 0
        fi

}

SetSimultaneousNS_VF(){

        local runtype=$1

        # Run Type
        # 0 : Running I/O each Namespaces of each Functions
        # 1 : Running I/O each Namespaces of all Functions
        # 2 : Running I/O all Namespaces of all Functions
        if [ $runtype -eq 0 ]; then
                simns=1; simvf=${numport};
                doLogEcho "============== IO ${simns}Namespaces and ${simvf} Functions ============== "
        elif [ $runtype -eq 1 ]; then
                simns=1; simvf=`expr ${numport} \* \( ${numvf} \+ 1 \)`;
                doLogEcho "============== IO ${simns}Namespaces and ${simvf} Functions ============== "
        else
                simns=${luncnt}; simvf=`expr ${numport} \* \( ${numvf} \+ 1 \)`;
                doLogEcho "============== IO ${simns}Namespaces and ${simvf} Functions ============== "
        fi

}

resetIntegrity() {

        local startvf=$1                #startvf, endvf (start VF, end VF)
        local endvf=$2                  #startvf, endvf (start VF, end VF)
        local intvvf=$3                 #intvvf : interval of virtual furnction
        local inc0dec1vf=$4             #inc0dec1vf : 0=increased interval, 1=decreased interval for VFs
        local resettype=$5              #resettype : 0=NVM Subsystem Reset | 1=Controller Reset | 2=PCI Functional Reset | 3=PCI Conventional Reset | 4=Fundamental Reset (via Quarch PERST# Glitch)
        local iteration=$6

        local testname
        declare -a testname
        local resettestname
        declare -a resettestname

        if [ $inc0dec1vf -eq 0 ]; then
                vfintvtype="nnumvf+"
                vflimittype="nnumvf<"
        else
                vfintvtype="nnumvf-"
                vflimittype="nnumvf>"
        fi

        for (( nnumvf=$startvf; $vflimittype=$endvf; $vfintvtype=$intvvf ))
        do
                if [ $nnumvf -ne 0 ]; then
                        numvf=`expr $nnumvf \- 1`
                else
                        numvf=$nnumvf
                fi
                #Enable Virtual Functions
                vfEnable $numvf $port $target $target2

                runtype=2
                doLogEcho "============== Run Type = "${runtype}" ============== "

                SetSimultaneousNS_VF $runtype

                for (( tp=0; tp<${#iotype[@]}; tp++ ))
                do
                        doLogEcho "============== IO Type = "${iotype[tp]}" ============== "

                        #Pre-condition(Write) for DIFDIX
                        echo WriteEnabled=1 >/iport${port}/target${target}
                        if [ ${fullwriteinit} -eq 0 ]; then
                                FullWriteForDIFDIX ${lunen[@]}
                        fi
                        doLogEcho "Complete Seq. Full Write"
                        #FullReadForDIFDIX ${lunen[@]}
                        #doLogEcho "Complete Seq. Full Read"

                        #Test ranges which are :ivided according to the number of VFs
                        #divide=`expr ${numport} \* ${#lunset[@]} \* ${simvf}`
                        divide=`expr ${#resetlun[@]} \* ${simvf}`
                        #The number of test loops
                        endloop=`expr ${numport} \* ${luncnt} \* \( ${numvf} \+ 1 \)`
                        numtarget=`expr ${numport} \* \( ${numvf} \+ 1 \)`

                        loopcnt=0
                        looptarget=0
                        lun=0
                        doLogEcho "The number of Endloop = $endloop"

                        for (( loop=0; loop<${endloop}; loop++ ))
                        do
                                doLogEcho "Current Loop Count = $loop"
                                doLogEcho "============== Running I/O ============== "
                                #Select Target according to number of namespace and number of namespace
                                SelectTarget $numvf $looptarget $numtarget
                                #Define Test Limit and Position
                                DefineTestArea $divide $queuetarget ${looptarget} ${lun}

                                testname[${loopcnt}]=${iotype[tp]}_target${queuetarget}_lun${lunen[$lun]}_numvf${numvf}_parreset_type_${resettype}_intv_${reset_intv}
                                doLogEcho "Test Name = ${testname[$loopcnt]}"
                                if [ ${randflag} -eq 1 ]; then
                                        if [ ${limitsize} -lt ${mdts} ]; then
                                                blocksize=`expr ${RANDOM} \% ${limitsize} \+ 1`
                                        else
                                                blocksize=`expr ${RANDOM} \% ${mdts} \+ 1`
                                        fi
                                fi

                                acctype=`expr ${RANDOM} \% 2`
                                if [ $acctype -eq 0 ]; then
                                        accsym="Sequential"
                                else
                                        accsym="Random"
                                fi

                                doLogEcho "Write Enable to target${queuetarget}"
                                echo WriteEnabled=1 >/iport${port}/target${queuetarget}

                                #Enable DIFDIX Option according to namespace
                                SetE2E ${lunen[lun]} ${queuetarget}

                                runtimeout=0
                                thread=${fixed_thread}
                                blocksize=${fixed_bs}
                                echo ${testname[${loopcnt}]},${thread},${blocksize},${runtimeout},${acctype},0,0,${lbatype},-1,60,0,1,1,0,1:1,1:1,0,-0 > /iport$port/target${queuetarget}lun${lunen[$lun]}

                                doLogEcho "Port=${port}, Target=${queuetarget}, NS=${lunen[$lun]}, #Test_Func=$simvf, #Test_NS=$simns, AccType=${accsym}, Blocksize=${blocksize}, Runtime=${runtimeout} "

                                if [ $lun -eq `expr $luncnt \- 1` ]; then
                                        doLogEcho "Test Name List = ${testname[@]}"
                                        if [ ${numvf} -eq 0 ] || ([ ${queuetarget} != ${target} ] && [ ${queuetarget} != ${target2} ]); then
                                                ResetTest testname[@] ${queuetarget} ${resettype} ${iteration} ${rst_intv_time} 1 &
                                                resetbg[looptarget]=$!
                                                doLogEcho "Reset Background Job's PID=${resetbg[looptarget]}"
                                                resettestname[looptarget]=${testname[0]}
                                        else
                                                doLogEcho "PF Reset should be skipped"
                                        fi
                                        let "looptarget+=1"
                                        lun=0
                                        loopcnt=0
                                else
                                        let "lun+=1"
                                        loopcnt=`expr $loopcnt \+ 1`
                                fi

                        done #target * lun

                        if [ $numvf -eq 0 ]; then
                                resettarget=`expr $numtarget \- 1`
                        else
                                resettarget=`expr $numtarget \- 2`
                        fi
                        doLogEcho "Reset Testname List=${resettestname[@]}, Number of Reset Target=${resettarget}"
                        statuscheck resettestname[@] $resettarget $poll
                        doLogEcho "Finish Reset Test in NumVFs=$numvf"

                        #Recovery each functions
                        doLogEcho "============== Recovery each target  ============== "
                        for (( looptarget=0; looptarget<${numtarget}; looptarget++ ))
                        do
                                #kill Background Job for Admin Command
                                if [ ${bgname[looptarget]} -ne 0 ]; then
                                        doLogEcho "Kill BackGround Job(PID=${bgname[looptarget]})"
                                        kill -9 ${bgname[looptarget]} 2 >/dev/null
                                fi
                                if [ ${resetbg[looptarget]} -ne 0 ]; then
                                        doLogEcho "Ctrl+C : Kill Reset BackGround Job(PID=${resetbg[looptarget]})"
                                        kill -9 ${resetbg[looptarget]} 2 >/dev/null
                                fi

                                sleep 30

                                #Select Target according to number of namespace and number of namespace
                                SelectTarget $numvf $looptarget $numtarget
                                if [ $numvf -eq 0 ] || ([ ${queuetarget} != ${target} ] && [ ${queuetarget} != ${target2} ]); then
                                        doLogEcho "Recovery Target=${target} after Kill Reset Backgroud Job"
                                        RecoveryTarget $queuetarget $resettype
                                fi

                                doLogEcho "Stop test for target${queuetarget}"
                                echo StopTests>/iport$port/target$queuetarget

                        done

                done #iotype

        done #numvf

}

SeqresetIntegrity() {

        local startvf=$1                #startvf, endvf (start VF, end VF)
        local endvf=$2                  #startvf, endvf (start VF, end VF)
        local intvvf=$3                 #intvvf : interval of virtual furnction
        local inc0dec1vf=$4             #inc0dec1vf : 0=increased interval, 1=decreased interval for VFs
        local resettype=$5              #resettype : 0=NVM Subsystem Reset | 1=Controller Reset | 2=PCI Functional Reset | 3=PCI Conventional Reset | 4=Fundamental Reset (via Quarch PERST# Glitch)
        local iteration=$6

        local testname
        declare -a testname
        local resettestname
        declare -a resettestname

        if [ $inc0dec1vf -eq 0 ]; then
                vfintvtype="nnumvf+"
                vflimittype="nnumvf<"
        else
                vfintvtype="nnumvf-"
                vflimittype="nnumvf>"
        fi

        for (( nnumvf=$startvf; $vflimittype=$endvf; $vfintvtype=$intvvf ))
        do
                if [ $nnumvf -ne 0 ]; then
                        numvf=`expr $nnumvf \- 1`
                else
                        numvf=$nnumvf
                fi
                #Enable Virtual Functions
                #doLogEcho "Debugging : $numvf $port $target $target2"
                vfEnable $numvf $port $target $target2

                runtype=2
                doLogEcho "============== Run Type = "${runtype}" ============== "

                SetSimultaneousNS_VF $runtype
                doLogEcho "Debugging : numport=${numport},lunnum=${#resetlun[@]},simvf=${simvf}"

                for (( tp=0; tp<${#iotype[@]}; tp++ ))
                do
                        doLogEcho "============== IO Type = "${iotype[tp]}" ============== "

                        #Pre-condition(Write) for DIFDIX
                        echo WriteEnabled=1 >/iport${port}/target${target}
                        if [ ${fullwriteinit} -eq 0 ]; then
                                FullWriteForDIFDIX ${lunen[@]}
                        fi
                        doLogEcho "Complete Seq. Full Write"
                        #FullReadForDIFDIX ${lunen[@]}
                        #doLogEcho "Complete Seq. Full Read"

                        #Test ranges which are :ivided according to the number of VFs
                        #divide=`expr ${numport} \* ${#lunset[@]} \* ${simvf}`
                        divide=`expr ${#resetlun[@]} \* ${simvf}`
                        #The number of test loops
                        endloop=`expr ${numport} \* ${luncnt} \* \( ${numvf} \+ 1 \)`
                        numtarget=`expr ${numport} \* \( ${numvf} \+ 1 \)`

                        loopcnt=0
                        looptarget=0
                        lun=0
                        doLogEcho "The number of Endloop = $endloop"

                        for (( looptarget=0; looptarget<${numtarget}; looptarget++ ))
                        do
                                doLogEcho "Current Loop Target = $looptarget"
                                doLogEcho "============== Running I/O ============== "
                                #Select Target according to number of namespace and number of namespace
                                SelectTarget $numvf $looptarget $numtarget

                                for (( lun=0; lun<${#lunen[@]}; lun++ ))
                                do
                                        #Define Test Limit and Position
                                        doLogEcho "Debugging : divide=${divide}"
                                        DefineTestArea $divide $queuetarget ${looptarget} ${lun}

                                        testname[lun]=${iotype[tp]}_target${queuetarget}_lun${lunen[$lun]}_numvf${numvf}_seqreset_type${resettype}
                                        doLogEcho "Test Name = ${testname[lun]}"

                                        doLogEcho "Debugging : $lun ${#lunen[@]}"
                                        if [ $lun -eq 0 ]; then
                                                resettestname[looptarget]=${testname[lun]}
                                        fi

                                        if [ ${randflag} -eq 1 ]; then
                                                if [ ${limitsize} -lt ${mdts} ]; then
                                                        blocksize=`expr ${RANDOM} \% ${limitsize} \+ 1`
                                                else
                                                        blocksize=`expr ${RANDOM} \% ${mdts} \+ 1`
                                                fi
                                        fi

                                        acctype=`expr ${RANDOM} \% 2`
                                        if [ $acctype -eq 0 ]; then
                                                accsym="Sequential"
                                        else
                                                accsym="Random"
                                        fi

                                        doLogEcho "Write Enable to target${queuetarget}"
                                        echo WriteEnabled=1 >/iport${port}/target${queuetarget}

                                        #Enable DIFDIX Option according to namespace
                                        SetE2E ${lunen[lun]} ${queuetarget}

                                        runtimeout=0
                                        thread=${fixed_thread}
                                        blocksize=${fixed_bs}
                                        echo ${testname[lun]},${thread},${blocksize},${runtimeout},${acctype},0,0,${lbatype},-1,60,0,1,1,0,1:1,1:1,0,-0 > /iport$port/target${queuetarget}lun${lunen[$lun]}
                                        doLogEcho "Port=${port}, Target=${queuetarget}, NS=${lunen[$lun]}, #Test_Func=$simvf, #Test_NS=$simns, AccType=${accsym}, Blocksize=${blocksize}, Runtime=${runtimeout} "

                                        loopcnt=`expr $loopcnt \+ 1`

                                done

                        done #target * lun

                        local iter
                        doLogEcho "============= Reset Iteration Number=${iteration} =============="
                        for (( iter=0; iter<${iteration}; iter++ ))
                        do
                                doLogEcho "============= Current Iteration Number=${iter} =============="
                                for (( looptarget=0; looptarget<${numtarget}; looptarget++ ))
                                do
                                        #Select Target according to number of namespace and number of namespace
                                        SelectTarget $numvf $looptarget $numtarget
                                        doLogEcho "Test Name List = ${resettestname[looptarget]}"

                                        if [ ${resettype} -eq 1 ] || [ ${resettype} -eq 2 ]; then
                                                if [ ${numvf} -eq 0 ] || ([ ${queuetarget} != ${target} ] && [ ${queuetarget} != ${target2} ]); then
                                                        ResetTest resettestname[looptarget] ${queuetarget} ${resettype} 1 ${rst_intv_time} 0
                                                else
                                                        doLogEcho "PF FLR should be skipped"
                                                fi
                                        else #if [ ${resettype} -eq 0 ] || [ ${resettype} -eq 3 ]; then
                                                if [ ${numvf} -eq 0 ] || ([ ${queuetarget} == ${target} ] || [ ${queuetarget} == ${target2} ]); then
                                                        ResetTest resettestname[looptarget] ${queuetarget} ${resettype} 1 ${rst_intv_time} 0
                                                        sleep 10
                                                else
                                                        doLogEcho "VF Hot Reset should be skipped"
                                                fi

                                        fi
                                done
                        done

                        #FinishTest 0 0
                        #sleep 120
                        doLogEcho "Finish Reset Test in NumVFs=$numvf"

                done #iotype

        done #numvf

}
HAVESUBS=1
