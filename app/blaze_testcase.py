import os
import sys
import time
from random import choice
from datetime import datetime
import blaze_precondition as pre
import blaze_util as bu
import json
import blaze_IO as bio
import blaze_precondition  as pre

#   Test ID = 'Compare_target12_lun1_numvf15_parreset_type_2_intv_1'
#   Threads per test' = '8'
#   Blocks per I/O' = '32'
#   I/Os per thread' = '0'
#   Seek Type = '0' (Sequential)
#   Opcode = '0' (Random)
#   Paused = '0'
#   Test Pattern = '3' (8-bit Incr)
#   Initiator = '-1' (All)
#   I/Os per pass = '60'
#   Multipathing = '0' (Default)
#   Blocks to Write = '1' (unused except for Rewrite)
#   Blocks to Skip = '1' (unused except for Rewrite)
#   Random Seed = '0'
#   Dedup Ratio = '1:1'
#   Comp Ratio = '1:1'
#   Dup Uniq = '0'
#   I/O Alignment = '0'
#   Level=0
#   Index=4829


class TCFullWrite:

    test_name_list = list()
    max_LBA = None
    device = None
    enabled_LUN = None
    size_per_ns = None
    IO_type = "Write"
    def __init__(self, device):
        self.device = device
        self.enabled_LUN = device.functions["phyFuncs"][0].enabled_LUN
        self.max_LBA = bu.get_max_LBA(self.device)
        self.size_per_ns = self.max_LBA / sum(self.enabled_LUN)
    def do_test(self):
        for each_funcs in self.device.funcs["phyFuncs"]:
            base_addr = "/iport"+self.device.port_num+"/target"
            bu.echo(base_addr+self.each_funcs.function_name, "WriteEnabled=1")
            bio.define_area()
            for each_LUN in each_funcs.LUNs:
                test_name = self.IO_type+each_LUN.LUN_name
                pre.pre_set_E2E(self.device, each_LUN)
                write_code = "{0},1,128kb,1024mb,0,0,0,0,0,0,0,1,1,0,1:1,1:1,0,-0".format(test_name,)
                bu.echo(base_addr+each_LUN.LUN_name, write_code)
                self.test_name_list.append(test_name)
            bu.status_check(each_funcs, self.test_list, 10)
        return self.test_name_list


class TCDataIntegrity:

    device = None
    is_pre_test = 0
    IO_type = ["Read", "Write", "Compare"]
    inc_dec_flag = 0
    vf_funcs = None
    ns_block_size = []
    INTRT_type_list = []
    test_name_list = None #string list that have tests test case excuting.
    random_flag = 0
    app_tag = "a53c"
    CMB_rand = 1
    vf_CMB_on = 0
    admin_on = 1
    log_file = None
    log_echo = None
    pattern = 7
    LBA_type = 3
    need_FullWrite = True
    runtime = 30
    thread = 256
    bg_job_list = []

    #initiallize by temp methon. It will be replaced by universal method like json.

    def __init__(self,device):
        self.device = device
        self.vf_funcs = self.device.functions["vFuncs"]
        today = datetime.now()
        formatted = "{0}-{1}-{2}-{3}:{4}:{5}".format(today.year,today.month, today.day, today.hour, today.minute, today.second)
        self.log_file = "Data_Integrity" + formatted
        self.log_echo = bu.log_echo(self.log_file, "a")


    def do_test(self):

        # initialize for io integrity

        pre.pre_initiallize(self.device)
        self.log_echo("Enabled IO Type = {0}".format(self.IO_type))
        max_LBA = bu.get_max_LBA(self.device)
        self.log_echo("Maximum LBA = {0}".format(max_LBA))
        bu.echo("/iport/"+self.device.prot_num+"/port","Retry=0")
        num_of_enabled_LUN, enabled_LUN_decimal = pre.pre_parse_enabled_LUN(self.device.functions["phyFuncs"][0])
        self.do_log_echo("Enabled Lun is {0}".format(enabled_LUN_decimal))
        self.do_log_echo("Enabled num of lun is {0}".format(num_of_enabled_LUN))
        pre.pre_set_default(self.device)
        self.ns_block_size = bu.get_block_size(self.device)
        pre.pre_set_LBA_type(self.pattern, self.LBA_type, self.device)
        generalTO = "3600000ms"
        pre.pre_set_time(
            GeneralTimeout=generalTO, ReadWriteTimeout=generalTO,
            TaskMgmtTimeout=generalTO, NoPathTimeout=generalTO
        )

        for run_type in range(0,3):
            test_LUN = bu.set_simultaneous_NS(self.device, run_type)
            for each_LUN in test_LUN:
                for each_IO_type in self.IO_type:
                    bu.ehco("/iport"+self.device.port_num+"/target"+each_LUN.LUN_name, "WriteEnabled=1")
                    if self.need_FullWrite:
                        TCFullWrite(self.device).do_test
                        self.need_FullWrite = False
                    bu.log_ehco("Complete Full Write.")
                    devide = int()
                    if run_type is 0:
                        devide = 2 if self.device.dual_mode else 1
                    if run_type is 1 or run_type is 2:
                        devide = sum(self.device.functions["phyFuncs"] + self.device.functions["vFuncs"])
                    if each_LUN.function.same_option_each_function:
                        intrt = each_LUN.function.type_of_INTRT
                        pre.pre_enable_INTRT(intrt, self.device.port_num, each_LUN.LUN_name)
                    else:
                        intrt = choice([1,3,7])
                        pre.pre_enable_INTRT(intrt, self.device.port_num, each_LUN.LUN_name)
                    self.INTRT_type_list.append(intrt)

                    """
                    vf - CMB
                    """
            time.slee(5)
            for idx, each_LUN in enumerate(test_LUN):
                limit_size = bio.define_area(sum(each_LUN.LUNs), each_LUN.function)
                runtime_out = bio.io_set_runtime(sum(each_LUN.LUNs), self.runtime)
                access_type = choice["Sequential", "Random"]
                bu.log_echo("Write Enable to target{0}".format(each_LUN.LUN_name))
                bu.echo("/iport"+self.device.port_num+"/target"+each_LUN.LUN_name, "WriteEnabled=1")
                pre.pre_set_E2E(self.device, each_LUN)
                bio.io_write_read(each_LUN, self.test_name_list[idx], self.thread,  self.ns_block_size[idx], runtime_out, access_type, self.LBA_type)

                if run_type is 0:
                    bu.status_check(self.device, self.test_name_list, 10)


















        # initialize for io integrity



