import blaze_device
import blaze_util
from blaze_util import echo



def except_reset(target_LUN,reset_type):
    reset_dict = \
    {
        0: "reset_nvm={0}",
        1: "reset_ctrl={0}",
        2: "reset_pci_func={0}",
        3: "reset_pci_conv={0}"
    }
    actual_reset = reset_dict[reset_type]
    echo("/proc/vlun/nvme", actual_reset.format(target_LUN))

