#include <linux/module.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

MODULE_INFO(vermagic, VERMAGIC_STRING);

__visible struct module __this_module
__attribute__((section(".gnu.linkonce.this_module"))) = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};

static const struct modversion_info ____versions[]
__used
__attribute__((section("__versions"))) = {
	{ 0x9d35aeec, __VMLINUX_SYMBOL_STR(module_layout) },
	{ 0xb97a8d7, __VMLINUX_SYMBOL_STR(param_ops_charp) },
	{ 0x90f9a77e, __VMLINUX_SYMBOL_STR(pci_unregister_driver) },
	{ 0xaceb4f8d, __VMLINUX_SYMBOL_STR(__pci_register_driver) },
	{ 0xe2d5255a, __VMLINUX_SYMBOL_STR(strcmp) },
	{ 0x27e1a049, __VMLINUX_SYMBOL_STR(printk) },
	{ 0x16305289, __VMLINUX_SYMBOL_STR(warn_slowpath_null) },
	{ 0x5824875d, __VMLINUX_SYMBOL_STR(__dynamic_dev_dbg) },
	{ 0x19203068, __VMLINUX_SYMBOL_STR(dev_notice) },
	{ 0x8323348f, __VMLINUX_SYMBOL_STR(pci_intx_mask_supported) },
	{ 0xeb87363c, __VMLINUX_SYMBOL_STR(dma_ops) },
	{ 0x78764f4e, __VMLINUX_SYMBOL_STR(pv_irq_ops) },
	{ 0x41c2eb24, __VMLINUX_SYMBOL_STR(arch_dma_alloc_attrs) },
	{ 0x751eb339, __VMLINUX_SYMBOL_STR(_dev_info) },
	{ 0x719df329, __VMLINUX_SYMBOL_STR(__uio_register_device) },
	{ 0x33ea1df0, __VMLINUX_SYMBOL_STR(sysfs_create_group) },
	{ 0x41d9cd2d, __VMLINUX_SYMBOL_STR(pci_enable_msix) },
	{ 0xa11b55b2, __VMLINUX_SYMBOL_STR(xen_start_info) },
	{ 0x731dba7a, __VMLINUX_SYMBOL_STR(xen_domain_type) },
	{ 0x33cdf8a, __VMLINUX_SYMBOL_STR(dma_supported) },
	{ 0x42c8de35, __VMLINUX_SYMBOL_STR(ioremap_nocache) },
	{ 0x4c03f08e, __VMLINUX_SYMBOL_STR(dev_err) },
	{ 0x30c58d84, __VMLINUX_SYMBOL_STR(pci_enable_device) },
	{ 0x2142697b, __VMLINUX_SYMBOL_STR(kmem_cache_alloc_trace) },
	{ 0x8a9809d6, __VMLINUX_SYMBOL_STR(kmalloc_caches) },
	{ 0xd4c104bd, __VMLINUX_SYMBOL_STR(pci_check_and_mask_intx) },
	{ 0xc92cc3eb, __VMLINUX_SYMBOL_STR(pci_intx) },
	{ 0x97764186, __VMLINUX_SYMBOL_STR(pci_cfg_access_unlock) },
	{ 0xba2decb4, __VMLINUX_SYMBOL_STR(pci_cfg_access_lock) },
	{ 0xfb6d4da3, __VMLINUX_SYMBOL_STR(pci_set_master) },
	{ 0x12c07462, __VMLINUX_SYMBOL_STR(pci_reset_function) },
	{ 0x122e3b52, __VMLINUX_SYMBOL_STR(pci_clear_master) },
	{ 0xa02d7891, __VMLINUX_SYMBOL_STR(remap_pfn_range) },
	{ 0x5944d015, __VMLINUX_SYMBOL_STR(__cachemode2pte_tbl) },
	{ 0xa50a80c2, __VMLINUX_SYMBOL_STR(boot_cpu_data) },
	{ 0xf272aa29, __VMLINUX_SYMBOL_STR(pci_disable_msix) },
	{ 0x37a0cba, __VMLINUX_SYMBOL_STR(kfree) },
	{ 0xf9a4f491, __VMLINUX_SYMBOL_STR(pci_disable_device) },
	{ 0xedc03953, __VMLINUX_SYMBOL_STR(iounmap) },
	{ 0x206a59d2, __VMLINUX_SYMBOL_STR(uio_unregister_device) },
	{ 0x8448f098, __VMLINUX_SYMBOL_STR(sysfs_remove_group) },
	{ 0x28318305, __VMLINUX_SYMBOL_STR(snprintf) },
	{ 0x205e9bea, __VMLINUX_SYMBOL_STR(pci_bus_type) },
	{ 0xdb7305a1, __VMLINUX_SYMBOL_STR(__stack_chk_fail) },
	{ 0x7429842b, __VMLINUX_SYMBOL_STR(pci_enable_sriov) },
	{ 0x227d2f05, __VMLINUX_SYMBOL_STR(pci_disable_sriov) },
	{ 0x696600a5, __VMLINUX_SYMBOL_STR(pci_num_vf) },
	{ 0x3c80c06c, __VMLINUX_SYMBOL_STR(kstrtoull) },
	{ 0xbdfb6dbb, __VMLINUX_SYMBOL_STR(__fentry__) },
};

static const char __module_depends[]
__used
__attribute__((section(".modinfo"))) =
"depends=uio";


MODULE_INFO(srcversion, "964321D18A4C7273AE8B3D5");
