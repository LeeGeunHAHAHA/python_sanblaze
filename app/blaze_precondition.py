import blaze_device
import json
from random import randint
from random import choice
import time
from blaze_util import echo
from blaze_util import grep
import re
import os
import sys

def tmp_log(message):
    print("this part will be replaced by log. {0}".format(message))

def pre_enable_CMB(type_of_CMB, port_num, target_name):

    CMB_type=  type_of_CMB
    CMB_target = "/iport" + port_num + "/target" + target_name
    CMB_file = open(CMB_target, "w")
    CMB_file.write("UseCMB="+str(CMB_type))
    CMB_file.close()
    tmp_log("CMB enabled")

def pre_enable_INTRT(type_of_INTRT, port_num, target_name):

    INTRT_type = type_of_INTRT
    INTRT_target = target_name

    echo("/iport"+port_num+"target" + INTRT_target, "InterruptTypes="+INTRT_type)





def pre_vf_enable_configure(device):
    port_num = device.port_num
    target_PF_list = device.functions["phyFuncs"]
    target_VF_list = device.functions["vFuncs"]

    restart_file = open("/proc/vlun/nvme")
    for idx, each_pf in enumerate(target_PF_list):

        PF_target = "/iport" + port_num + "/target" + each_pf.function_name
        PF_file = open(PF_target,"w")
        PF_file.write("NumVFs=0")
        tmp_log("vf = 0 for stable")
        time.sleep(3)
        pre_enable_CMB(each_pf.type_of_CMB, port_num, each_pf.function_name)
        pre_enable_INTRT(each_pf.type_of_INTRT, port_num, each_pf.function_name)
        restart_file.write("restart=" + each_pf.function_name)

    time.sleep(10)

    for each_pf in target_PF_list:

        PF_target = "/iport" + port_num + "/target" + each_pf.function_name
        PF_file = open(PF_target, "w")
        PF_file.write("NumVFs="+each_pf.num_of_vf)
        tmp_log("enable virtual function")
        time.sleep(10)

    for each_func in target_VF_list:
        if each_func.same_option_each_function:
            pre_enable_CMB(randint(0,3), port_num, each_func.function_name)
            pre_enable_INTRT(choice([0,3,7]), port_num, each_func.function_name)
            restart_file.write("restart=" + each_func.function_name)

    time.sleep(10)


    def vf_configure():
        print("not implemented. This will be used for modfying enable information given device")

    return vf_configure()


def pre_initialize(device):

    port_num = device.port_num
    PF_list = device.functions["phyFuncs"]
    VF_list = device.functions["vFuncs"]

    stop_clear_addr = "/iport"+port_num+"/target"

    for each_pf in PF_list:
        stop_clear_file = open(stop_clear_addr+each_pf.function_name)
        stop_clear_file.write("StopTests")
        stop_clear_file.write("ClearTests")

    for each_vf in VF_list:
        stop_clear_file = open(+stop_clear_addr+each_vf.function_name)
        stop_clear_file.write("StopTests")
        stop_clear_file.write("ClearTests")

    port_file = open("/iport"+port_num+"/port")
    port_file.write("TimeoutErrorRecovery=0")
    port_file.write("TestLimits=0,0,0")

    admin_cmd_addr ="/sys/module/nvme/parameters/"
    echo(admin_cmd_addr+"admin_timeout", "20000")
    echo(admin_cmd_addr+"abort_timeout", "30000")



def pre_get_max_lba(device):

    port_num = device.port_num
    target = device.functions["phyFuncs"][0]
    result = grep("/iport"+port_num+"/target"+target+"lun1", "blocks")
    patern = re.compile("\d+ blocks")
    found = []
    for line in result:
        found = patern.findall(line)
    return found.pop()[:-6] if found is not [] else -1


def pre_set_default(device):

    port_num = device.port_num
    for func in device.functions["phtFuncs"]:
        echo("/iport"+port_num+"/target"+func.function_name, "InterruptTypes=7")
        echo("/iport"+port_num+"/target"+func.function_name, "UseCMB=0")
        echo("/proc/vlun/nvme" ,"restart="+func.function_name)

    echo("/iport"+port_num+"/port", "TestLimits=0.0.0")
    echo("/iport"+port_num+"/port", "NoT10DIF=0")
    echo("/iport"+port_num+"/port", "PRCHK=0,0")
    echo("/iport"+port_num+"/port", "AppTag=0,ffff")

    time_set = {
        "GeneralTimeout" : "15000ms",
        "ReadWriteTimeout" : "15000ms",
        "TaskMgmtTimeout": "15000ms",
        "NoPathTimeout": "15000ms"
    }
    pre_set_timeout(**time_set)

def pre_set_timeout(**time_set):

    GTO = time_set["GeneralTimeout"]
    RWTO = time_set["ReadWriteTimeout"]
    TMTO = time_set["TaskMgmtTimeout"]
    NPTO = time_set["NoPathTimeout"]

    echo("/iport0/port", "GeneralTimeout=" + GTO)
    echo("/iport0/port", "ReadWriteTimeout=" + RWTO)
    echo("/iport0/port", "TaskMgmtTimeout=" + TMTO)
    echo("/iport0/port", "NoPathTimeout="+ NPTO)


def pre_parse_enabled_LUN(enabled_LUN):
    bit_to_decimal =[idx+1 for idx, bit in enumerate(enabled_LUN) if bit]
    return sum(enabled_LUN), bit_to_decimal



def pre_set_LBA_type(pattern, lbatype, device):

    port_num = device.port_num

    if pattern is "100":
        tmp_log("-------------------using timestamped pattern--------------------")
        echo("/iport" + port_num +"/port" , lbatype)


def pre_set_E2E(device, selected_LUN):

    port_num = selected_LUN.func.device.port_num
    num_of_LUN = selected_LUN.func.num_of_LUN
    target_LUN = selected_LUN
    APPTAG = selected_LUN.APPTAG
    is_random_PRACT = selected_LUN.random_PRACT

    if is_random_PRACT is 0:
        PRACT = randint(0, 2) if num_of_LUN not in {20, 26, 30, 32} else 0
    elif is_random_PRACT is 1:
        PRACT = 1
    else:
        PRACT = 0

    if num_of_LUN >= 17:
        tmp_log("PRACT={0} in target{1}lun{2}".format(PRACT, target_LUN.LUN_name, num_of_LUN))
        if PRACT is 0:
            echo("/iport"+port_num+"/port", "NoT10DIF=2")
        else:
            echo("/iport"+port_num+"/port", "NoT10DIF=0")
        echo("/iport"+port_num+"/port", "PRCHK =7,1")
        PRCHK = 7
        echo("/iport"+port_num+"/port", "PRCHK ="+APPTAG+",ffff")
    else:
        echo("/iport"+port_num+"/port", "NoT10DIF=0")
        echo("/iport"+port_num+"/port", "PRCHK =0,0")
        PRCHK = 0
        echo("/iport"+port_num+"/port", "PRCHK =0,ffff")
    selected_LUN.PRACT = PRACT
    selected_LUN.PCHK = PRCHK

#def pre_Identify_controller(target_func, sleep_second):
#    target = target_func

def pre_finish_test(device, test_case,all_stop):
    phyFuncs = device.functions["phyFuncs"]
    vFuncs = device.functions["vFuncs"]
    all_funcs = phyFuncs+vFuncs

    for each_funcs in all_funcs :
        tmp_log("Stop test for {0} target".format(each_funcs.function_name))
        echo("/iport"+device.port_num+"/target"+each_funcs.function_name, "StopTests")

    while test_case.back_ground_admin:
        os.kill(test_case.back_ground_process.pop(), 9 )
    while test_case.back_ground_reset:
        os.kill(test_case.back_ground_process.pop(), 9 )

    if all_stop:
        sys.exit()







if __name__ == "__main__":
    echo("123", "123")

    with open("device_input.json") as file:
        data = json.loads(file.read())
    dev = blaze_device.device_configuration(**data)





