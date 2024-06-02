import os
import json
import shutil
import pretty_errors		# pip install pretty_errors
from posixpath import join
from string import Template
from pprint import pprint


NCS_PATH		= 'C:/ncs/v2.5.0'
MY_DIR			= os.path.dirname(__file__).replace('\\', '/')
BOSL_VERSION	= '1.0.4'		# default - it may be changed in _setup()

BASE_DIR		= None
BUILD_DIR		= None
COMMANDS_JSON	= None

PLATFORM_TXT	= None
DST_DIR			= None
INCLUDES_DST	= None
PLATFORM_DST	= None

defines			= []
other_options	= []
include_paths	= ['C:/ncs/v2.5.0/zephyr/kernel/include', 'C:/ncs/v2.5.0/zephyr/arch/arm/include']

#-------------------------------------------------------------------------------
def _setup(sample_name: str) -> None:
	global BOSL_VERSION, BASE_DIR, BUILD_DIR, COMMANDS_JSON
	global PLATFORM_TXT, DST_DIR, INCLUDES_DST, PLATFORM_DST

	BOSL_VERSION	= os.getenv("BOSL_VERSION")

	BASE_DIR		= join(MY_DIR, 'zephyr_samples', sample_name)
	BUILD_DIR		= join(BASE_DIR, 'build')
	COMMANDS_JSON	= join(BUILD_DIR, 'compile_commands.json')

	PLATFORM_TXT	= join(MY_DIR, 'templates', 'platform.txt')
	DST_DIR			= join(MY_DIR, f'bosl/hardware/nrf9160/{BOSL_VERSION}')
	INCLUDES_DST	= join(DST_DIR, 'inc')
	PLATFORM_DST	= join(DST_DIR, 'platform.txt')

	if os.path.isdir(BASE_DIR) == False:
		raise ModuleNotFoundError(f'Base Zephyr sample does not exist "{BASE_DIR}".')

#-------------------------------------------------------------------------------
def _get_compile_command(json_file_path: str) -> str:
	with open(json_file_path, 'r') as f:
		json_data = json.load(f)
		compile_cmd = json_data[0]['command']
		return compile_cmd

#-------------------------------------------------------------------------------
def _parse_compile_options(compile_cmd: str) -> None:
	skip_next = False
	compile_tokens = compile_cmd.split(' ')
	for token in compile_tokens:
		if token.startswith('-D'):
			if not 'MBEDTLS' in token:
				defines.append(token)
		elif token.startswith('-I'):
			include_paths.append(token[2:])
		else:
			if skip_next == True:
				skip_next = False
				continue
			elif token.endswith('arm-zephyr-eabi-gcc.exe'):
				continue
			elif token.endswith('arm-zephyr-eabi-g++.exe'):
				continue
			elif token.startswith('-imacros'):
				# imacros paths are hardcoded in platform.txt
				# -imacros are followed by another token
				skip_next = True
				continue
			elif token.startswith('-isystem'):
				# - We do not seem to need '-isystem' option
				# -isystem is followed by another token
				skip_next = True
				continue
			elif token.startswith('--sysroot'):
				# - We do not seem to need '--sysroot' option
				continue
			elif token.startswith('-fmacro-prefix-map'):
				# - We do not seem to need '-fmacro-prefix-map' option
				continue
			elif token.startswith('-O') or token.startswith('-g'):
				# this is an optimisation option. They are hardcoded in platform.txt
				continue
			elif token.startswith('-fdiagnostics-color'):
				# although showing warnings and errors in colour is nice, it
				# doesn't play well with Arduino IDE
				other_options.append('-fno-diagnostics-color')
				continue
			elif token  == '-o':
				# We don't need output file switch in platform.txt
				# -o is followed by another token
				skip_next = True
				continue
			elif token  == '-c':
				# We don't need input file switch in platform.txt
				# -c is followed by another token
				skip_next = True
				continue
			elif 'C:/ncs' in token:
				print(f'Warning: unknown option "{token}"')
			else:
				other_options.append(token)

#-------------------------------------------------------------------------------
def _copy_include_dir(src_base: str, src_path: str, dst_path: str = '', recursive: bool = True) -> None:
	full_src_path = join(src_base, src_path)
	if recursive == True:
		for root, dirs, files in os.walk(full_src_path):
			for file in files:
				if file.endswith('.h'):
					src = join(root, file)
					dst = src.replace(src_base, INCLUDES_DST)
					if dst_path != '':
						dst = dst.replace(src_path, dst_path)
					os.makedirs(os.path.dirname(dst), exist_ok=True)
					#print(f'Copying:')
					#print(f'  {src}')
					#print(f'  {dst}')
					shutil.copy(src, dst)
	else:
		for file in os.listdir(full_src_path):
			if file.endswith('.h'):
				src = join(full_src_path, file)
				dst = src.replace(src_base, INCLUDES_DST)
				if dst_path != '':
					dst = dst.replace(src_path, dst_path)
				os.makedirs(os.path.dirname(dst), exist_ok=True)
				shutil.copy(src, dst)

#-------------------------------------------------------------------------------
def _collect_includes() -> None:
	if os.path.exists(INCLUDES_DST) == True:
		shutil.rmtree(INCLUDES_DST)

	_copy_include_dir(MY_DIR, 'Arduino-Zephyr-API/cores/arduino')
	_copy_include_dir(MY_DIR, 'Arduino-Zephyr-API/variants', recursive=False)
	_copy_include_dir(MY_DIR, 'Arduino-Zephyr-API/variants/nrf9160dk_nrf9160_ns',	'Arduino-Zephyr-API/variants')
	_copy_include_dir(MY_DIR, 'Arduino-Zephyr-API/libraries/Wire')

	include_paths.sort()
	for include_path in include_paths:
		if os.path.exists(include_path):
#			print(f' Collecting {include_path}')
			if 'generated' in include_path:
				if '/zephyr/' in include_path:
					path = include_path[len(BUILD_DIR)+1:]
					_copy_include_dir(BUILD_DIR, path, 'generated/zephyr')
				elif '/nrf/' in include_path:
					path = include_path[len(BUILD_DIR)+1:]
					_copy_include_dir(BUILD_DIR, path, 'generated/nrf')
				elif '/tfm/' in include_path:
					path = include_path[len(BUILD_DIR)+1:]
					_copy_include_dir(BUILD_DIR, path, 'generated/tfm')
			elif include_path.startswith(BUILD_DIR) and include_path != BUILD_DIR:
				path = include_path[len(BUILD_DIR)+1:]
				_copy_include_dir(BUILD_DIR, path, path)
			elif include_path.startswith(BASE_DIR):
				continue
			elif include_path.startswith(NCS_PATH):
				path = include_path[len(NCS_PATH)+1:]
				_copy_include_dir(NCS_PATH, path, path)

#-------------------------------------------------------------------------------
def _update_platform_txt() -> None:
	zephyr_paths	 = ''
	nrf_paths		 = ''
	for include_path in include_paths:
		if os.path.exists(include_path) and include_path.startswith(NCS_PATH):
			include_path = include_path[len(NCS_PATH)+1:]
			if include_path.startswith('zephyr/'):
				zephyr_paths += f'"-I{{inc.path}}/{include_path}" '
			elif include_path.startswith('nrf'):
				nrf_paths += f'"-I{{inc.path}}/{include_path}" '
			elif include_path.startswith('modules/') and \
				 not 'Arduino-Zephyr-API' in include_path:
				# Arduino-Zephyr-API include paths are hardcoded in platform.txt
				nrf_paths += f'"-I{{inc.path}}/{include_path}" '

	compiler_defines = ''
	for define in defines:
		compiler_defines += define + ' '

	compiler_options = ''
	c_options		 = ''
	cpp_options		 = ''
	for option in other_options:
		if option in ['-std=c99', '-Wno-pointer-sign', '-Werror=implicit-int']:
			c_options += option + ' '
		elif option in ['-nostdinc++', '-std=c++11', '-fno-rtti']:
			cpp_options += option + ' '
		else:
			compiler_options += option + ' '

	with open(PLATFORM_TXT, 'r') as f:
		template_str = f.read()
	template	  = Template(template_str)
	template_str = template.substitute(
		version			 = BOSL_VERSION, 
		zephyr_paths	 = zephyr_paths,
		nrf_paths		 = nrf_paths,
		compiler_defines = compiler_defines,
		compiler_options = compiler_options,
		c_options		 = c_options,
		cpp_options		 = cpp_options
	)

	with open(PLATFORM_DST, 'w') as f:
		f.write(template_str)

#-------------------------------------------------------------------------------
def proc_compile_cmd(sample_name: str) -> None:
	_setup(sample_name)

	compile_cmd = _get_compile_command(COMMANDS_JSON)
	_parse_compile_options(compile_cmd)

	_update_platform_txt()
	_collect_includes()

################################################################################
if __name__ == "__main__":
	proc_compile_cmd('at_client')
#	proc_compile_cmd('BoSL-cam')

