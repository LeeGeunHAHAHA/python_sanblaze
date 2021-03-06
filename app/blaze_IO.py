import blaze_device
from blaze_util import echo
import  blaze_util as bu
import blaze_precondition


def io_define_test_area(num_of_LUN, target):
    max_LBA = bu.get_MAX_LBA(target.device)
    limit_size = int(max_LBA)/num_of_LUN
    size_per_ns = int(max_LBA)/num_of_LUN
    return limit_size


def io_write_read(target_LUN, test_name, thread, block_size, runtime_out, access_type, LBA_type):
    port_num = target_LUN.func.device.port
    base_addr = "/iport"+port_num+"/target"
    LUN_name = target_LUN.LUN_name
    write_format = "{0},{1},{2},{3},{4},{5},0,0,{6},-1,60,0,1,1,0,1:1,1:1,0,-0"
    echo(base_addr+LUN_name, write_format.format(test_name, thread, block_size, runtime_out, access_type, LBA_type))

def io_set_runtime(num_ns, runtime):
    sim_ns = num_ns
    runtime = sim_ns * runtime
    runtime_out = str(runtime) + "s"
    return runtime_out






