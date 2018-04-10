import json

with open("device_input.json") as file:
    data = json.loads(file.read())

def device_configuration(**data):
    vfunc_start_num = 0

    param = data["dev0_input"]
    dev_name = param["dev_name"]
    port_num = param["port_num"]
    dual_mode = param["dual_mode"]

    dev = Device(dev_name, port_num, dual_mode)
    function_information_0 = param["function0_info"]
    function_0 = Function(dev, 1, **function_information_0)
    function_0.make_lun_list(function_0, **function_information_0)

    for funcs in range(int(function_0.num_of_LUN)):
        function_information_0["function_name"] = str(vfunc_start_num + funcs)
        tmp_func = Function(dev, 0,  **function_information_0)
        tmp_func.make_lun_list(tmp_func, **function_information_0)
        dev.functions["vFuncs"].append(tmp_func)
    vfunc_start_num += int(function_0.num_of_LUN)
    dev.functions["phyFuncs"].append(function_0)

    if dual_mode:

        function_information_1 = param["function1_info"]
        function_1 = Function(dev, 1, **function_information_1)
        function_1.make_lun_list(function_1, **function_information_1)

        for funcs in range(int(function_1.num_of_LUN)):
            print(funcs)
            function_information_1["function_name"] =str(vfunc_start_num + funcs)
            tmp_func = Function(dev, 0,  **function_information_1)
            tmp_func.make_lun_list(tmp_func, **function_information_1)
            dev.functions["vFuncs"].append(tmp_func)
        vfunc_start_num += int(function_1.num_of_LUN)
        dev.functions["phyFuncs"].append(function_1)
    print(dev.functions)
    return dev

class Device:

    dev_name = None #device name.
    port_num = None #port num that device is connected.
    dual_mode = None #dual =1 , single =0
    functions = {"phyFuncs": [], "vFuncs": []}

    def __init__(self, dev_name, port_num, dual_mode):
        self.dev_name = dev_name
        self.port_num = port_num
        self.dual_mod = dual_mode
        self.debug()

    def debug(self):
        print("device_info")
        print(self.dev_name, self.port_num, self.dual_mod, self.functions, end = "\n\n")


class Function:

    device = None
    phy_or_vir = None #(0 = vir, 1 =phy)
    function_name = None

    num_of_LUN = None
    num_of_queue = None
    queue_depth = None
    type_of_CMB = None
    type_of_interrupt = None #legacy = 0, msi = 1, msi-x =2

    LUNs= list()

    def __init__(self, device, phy_or_vir,  **param):
        self.device = device
        self.phy_or_vir = phy_or_vir
        self.num_of_queue = param["num_of_queue"]
        self.queue_depth = param["queue_depth"]
        self.type_of_CMB = param["type_of_CMB"]
        self.type_of_interrupt = param["type_of_interrupt"]

        self.num_of_LUN = param["num_of_LUN"]
        self.function_name = param["function_name"]
        self.debug()

    def debug(self):
        print("Function Info.{0}".format("physical" if self.phy_or_vir else "virtual"))
        print(self.device, self.phy_or_vir, self.num_of_queue, self.queue_depth, self.type_of_CMB, self.type_of_interrupt, self.num_of_LUN, self.function_name, end = '\n\n')

    def make_lun_list(self,funct, **param):
        lun_info = param["LUN_info"]
        self.LUNS = [LUN(LUN_name,funct, **lun_info) for LUN_name in range(int(self.num_of_LUN))]
        print(self.LUNS)


class LUN:

    LUN_name = None
    func = None

    block_size = None #(512 or 4096)
    PRACT = None
    PRCHK = None #(3bit data)
    APPTAG = None #(2byte-hex)

    meta_size = None #(0, 8, 64)
    PI = None #(disable/first_8bit/last_8bit)
    formatted_LBA = None #(Extended/separate)

    def __init__(self,LUN_name, func, **param):
        self.LUN_name =  str(func.function_name) + "lun" + str(LUN_name)
        self.func = func
        self.block_size = param["block_size"]
        self.PRACT = param["PRACT"]
        self.PRCHK = param["PRCHK"]
        self.APPTAG = param["APPTAG"]
        self.meta_size = param["meta_size"]
        self.PI = param["PI"]
        self.formatted_LBA = param["formatted_LBA"]
        self.debug()

    def debug(self):
        print("LUN INFO")
        print(self.LUN_name, self.func, self.block_size, self.PRACT, self.PRCHK, self.APPTAG, self.meta_size, self.PI, self.formatted_LBA, end = "\n\n")


if __name__ == "__main__":
    device_configuration(**data)