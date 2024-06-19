from proc_compile_cmd import proc_compile_cmd
from proc_link_cmd import proc_link_cmd

################################################################################
if __name__ == "__main__":
#	BASE_ZEPHYR_SAMPLE = 'BoSL-cam'
	BASE_ZEPHYR_SAMPLE = 'everything'

	print(f'Building package based on zephyr_sample/{BASE_ZEPHYR_SAMPLE}')

	print(f'    Processing compile command...')
	proc_compile_cmd(BASE_ZEPHYR_SAMPLE)

	print(f'    Processing link command...')
	proc_link_cmd(BASE_ZEPHYR_SAMPLE)

