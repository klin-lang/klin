/* GD32VW553HMQ: 4M flash / 320K RAM (LCKFB stamp; edit LENGTH for your SKU). */
ENTRY(_start)

MEMORY
{
	FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 4096K
	RAM (xrw)  : ORIGIN = 0x20000000, LENGTH = 320K
}

SECTIONS
{
	.text :
	{
		. = ALIGN(4);
		KEEP(*(.text.init))
		*(.text)
		*(.text.*)
		*(.rodata)
		*(.rodata*)
		. = ALIGN(4);
	} >FLASH

	PROVIDE(_etext = .);

	.data :
	{
		. = ALIGN(4);
		_data_vma = .;
		*(.data)
		*(.data.*)
		*(.sdata)
		*(.sdata.*)
		. = ALIGN(4);
		_edata = .;
	} >RAM AT>FLASH
	_data_lma = LOADADDR(.data);

	.bss (NOLOAD) :
	{
		. = ALIGN(4);
		_sbss = .;
		*(.sbss*)
		*(.bss*)
		*(COMMON)
		. = ALIGN(4);
		_ebss = .;
	} >RAM

	PROVIDE(_eusrstack = ORIGIN(RAM) + LENGTH(RAM));
	PROVIDE(__global_pointer$ = _data_vma + 0x800);
}
