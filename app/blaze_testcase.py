import os
import sys
import time
import random
import blaze_precondition as pre
import blaze_util as bu
import json
import blaze_IO as bio

class TC_full_write():
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



class TC_Data_integrity:
    IO_type = ["Read", "Write", "Compare"]
    device = None
    in_dec_flag = 0
    vf_funcs = None
    test_name_list = None
    random_flag = 0
    def __init__(self,device):
        self.device = device
        self.vf_funcs = self.device.functions["vFuncs"]

    def do_test(self):
        vf_list_sampleing ={
            0:self.vf_funcs,
            1:[each_vf for idx, each_vf in enumerate(self.vf_funcs) if idx % 8 is 0],
            2:reversed(self.vf_funcs)
        }
        pre.pre_vf_enable_configure(self.device)
        max_LBA = bu.get_MAX_LBA(self.device)
        for each_vf in vf_list_sampleing[self.in_dec_flag]:
            base_addr = "/iport" + each_vf.device.port_num+"/target"
            bu.echo(base_addr+each_vf.function_name, "WriteEabled=1")
            full_write_list = None
            for each_IO_type in self.IO_type:
                bu.log_echo("starting IO")
                if full_write_list is None:
                    full_write_list = TC_full_write(each_vf.device).do_test()
                for each_LUN in each_vf.LUNs:
                    runtime_out = bio.set_runtime(each_vf.num_of_lun)
                    access_type = ["Sequential", "Random"]
                    bio.io_write_read(each_LUN,each_LUN.LUN_name+each_IO_type, max_LBA, runtime_out, random.choice(access_type) if self.random_flag else "Sequential")

                #def io_wrie_read(target_LUN, test_name, thread, block_size, runtime_out, access_type, LBA_type):











