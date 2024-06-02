import os
import subprocess
import shutil
import pretty_errors		# pip install pretty_errors
from posixpath import join
from glob import glob
from string import Template
from pprint import pprint


BOSL_VERSION	= '1.0.4'		# default - it may be changed in _setup()

BASE_DIR		= None
BUILD_DIR		= None

PLATFORM_TXT	= None
DST_DIR			= None
PLATFORM_DST	= None

LIBS_DST		= None
PLATFORM_DST	= None

objects		= []
whole_libs	= []
partial_libs= []
options		= ['-gdwarf-4']

#-------------------------------------------------------------------------------
def _setup(sample_name: str) -> None:
	global BOSL_VERSION, BASE_DIR, BUILD_DIR
	global PLATFORM_TXT, DST_DIR, LIBS_DST, PLATFORM_DST

	BOSL_VERSION	= os.getenv("BOSL_VERSION")

	MY_DIR			= os.path.dirname(__file__).replace('\\', '/')
	BASE_DIR		= join(MY_DIR, 'zephyr_samples', sample_name)
	BUILD_DIR		= join(BASE_DIR, 'build')

	PLATFORM_TXT	= join(MY_DIR, 'templates', 'platform.txt')
	DST_DIR			= join(MY_DIR, f'bosl/hardware/nrf9160/{BOSL_VERSION}')
	LIBS_DST		= join(DST_DIR, 'lib')
	PLATFORM_DST	= join(DST_DIR, 'platform.txt')

	if os.path.isdir(BASE_DIR) == False:
		raise(f'Base Zephyr sample does not exist "{BASE_DIR}".')

#-------------------------------------------------------------------------------
def _parse_link_cmd() -> None:
	FINAL_RSP = 'CMakeFiles/zephyr_final.rsp'
	if not os.path.exists(FINAL_RSP):
		# Clean files produced by the linking process
		for f in glob(join('zephyr', 'zephyr.*')):
			#print(f'Removing {f}')
			os.remove(f)
#		print('Linking...')
		output = subprocess.check_output('ninja --verbose -d keeprsp', shell=True, encoding="utf-8")

		# save output for reference
		with open('linker_commands.log', 'w') as f:
			f.write(output)

	# Command we are interested in looks something like this:
	#	    C:\ncs\toolchains\c57af46cb7\opt\zephyr-sdk\arm-zephyr-eabi\bin\arm-zephyr-eabi-gcc.exe  
	#	        -gdwarf-4 @CMakeFiles\zephyr_final.rsp 
	#	        -o zephyr\zephyr.elf 

	with open(FINAL_RSP, 'r') as f:
		rsp = f.read()
	is_whole_lib= True
	for o in rsp.split(' '):
		if o != '':
			if o.endswith('.obj') or o.endswith('.o'):
				if o.endswith('isr_tables.c.obj'):
					continue
				if o.endswith('offsets.c.obj'):
					continue
				if o.endswith('empty_file.c.obj'):
					continue
				objects.append(o)
			elif o == '-Wl,--whole-archive':
				is_whole_lib = True
			elif o == '-Wl,--no-whole-archive':
				is_whole_lib = False
			elif o.endswith('.a'):
				if o.endswith('libapp.a'):
					# Skip libapp.a - it contains objects from the sample we are collecting
					# linker options from. Arduino sketch will provide it's own object files
					#print('Skipping libapp.a')
					continue
				elif is_whole_lib == True:
					whole_libs.append(o)
				else:
					partial_libs.append(o)
			else:
				options.append(o)
	#print('Whole libraries:')
	#pprint(whole_libs)
	#print()
	#print('Partial libraries:')
	#pprint(partial_libs)
	#print()
	#print('Other options')
	#pprint(options)

#-------------------------------------------------------------------------------
def _update_platform_txt() -> None:
	with open(PLATFORM_DST, 'r') as f:
		platform_str = f.read()
	linker_options = ''
	for option in options:
		if option.endswith('.map'):
			option = '-Wl,-Map={build.path}/{build.project_name}.map'
		elif option.startswith('-mcpu'):
			option = '-mcpu={build.mcu}'
		elif option.startswith('-L'):
			continue
		elif option == '-Wl,--print-memory-usage':
			# We will insert this option manually where needed. But we don't
			# want it in pre0 linking stage
			continue
#		elif option == '-Wl,--orphan-handling=warn':
#			# We don't need orphan section warnings
#			continue
		elif option == '-u_printf_float':
			# TODO: linking doesn't work with #-u_printf_float. Why
			continue
		elif option == '-T' or option == 'zephyr/linker.cmd':
			continue
		linker_options += option + ' '

	precompiled_obj_names = ''
	for obj in objects:
		obj_name = f'"{{libs.path}}/{os.path.basename(obj)}" '
		precompiled_obj_names += obj_name

	whole_lib_names = ''
	for lib in whole_libs:
		lib_name = f'"{{libs.path}}/{os.path.basename(lib)}" '
		whole_lib_names += lib_name

	partial_lib_names = ''
	for lib in partial_libs:
		lib_name = f'"{{libs.path}}/{os.path.basename(lib)}" '
		partial_lib_names += lib_name

	template	  = Template(platform_str.replace('$$', '$'))
	template_str = template.substitute(
		linker_options		= linker_options,
		precompiled_objects	= precompiled_obj_names,
		whole_lib_names	 	= whole_lib_names,
		partial_lib_names	= partial_lib_names)

	with open(PLATFORM_DST, 'w') as f:
		f.write(template_str)

#-------------------------------------------------------------------------------
def _collect_libs() -> None:
	if os.path.exists(LIBS_DST) == True:
		shutil.rmtree(LIBS_DST)
	os.makedirs(LIBS_DST)
	
	for lib in objects + whole_libs + partial_libs:
		#print(lib)
		shutil.copy(lib, LIBS_DST)

	shutil.copy('tfm/bin/tfm_s.hex',			 LIBS_DST)
	shutil.copy('zephyr/tfm_secure.hex',		 LIBS_DST)
	shutil.copy('zephyr/linker.cmd',			 LIBS_DST)
	shutil.copy('zephyr/linker_zephyr_pre0.cmd', join(LIBS_DST, 'linker_pre0.cmd'))

#-------------------------------------------------------------------------------
def proc_link_cmd(sample_name: str) -> None:
	_setup(sample_name)

	os.chdir(BUILD_DIR)

	_parse_link_cmd()
	_update_platform_txt()
	_collect_libs()

################################################################################
if __name__ == "__main__":
	proc_link_cmd('at_client')
#	proc_link_cmd('BoSL-cam')
