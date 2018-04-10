import device
import json

with open("device_input.json") as file:
    data = json.loads(file.read())
device.device_configuration(**data)

"""
device information


dev_name = None #device name.
port_num = None #port num that device is connected.
dual_mode = None #dual =1 , single =0
functions = {"phyFuncs": [], "vFuncs": []}

"""

"""

function information

device = None
phy_or_vir = None #(0 = vir, 1 =phy)
function_name = None
num_of_LUN = None
num_of_queue = None
queue_depth = None
type_of_CMB = None
type_of_interrupt = None #legacy = 0, msi = 1, msi-x =2

"""


def pre_vf_enable_configure(dev):
    port_num = dev.port_num
    target_PF_list = dev.functions["phyFuncs"]
    target_VF_list = dev.functions["vFuncs"]

    for pf in target_PF_list:
        print(pf)

    for vf in target_VF_list:
        print(vf)

    def vf_configure():


    return vf_configure()




