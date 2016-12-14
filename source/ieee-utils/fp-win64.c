/* fp-win.c
 * 
 * Author: Brian Gladman with changes by aweatherguy
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or (at
 * your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

#ifndef WIN32
#error "Cannot build with fp-win64.c on a non-windows build (WIN32 macro not set)"
#endif

#include <float.h>

#include <config.h>
#include <gsl/gsl_ieee_utils.h>
#include <gsl/gsl_errno.h>

#include <Windows.h>        // for GetSystemInfo

const char *fp_env_string = "round-to-nearest,double-precision,mask-all";

int
gsl_ieee_set_mode (int precision, int rounding, int exception_mask)
{
	unsigned int currentMode;
    unsigned int pmode = 0;
    unsigned int mode = _DN_SAVE;
    unsigned int mask = _MCW_DN | _MCW_RC | _MCW_EM;
    //
    // on 64-bit processors, altering precision or the infinity mode
    // is not possible and will cause an assertion if attempted.
    // for some reason, the infinity mode is not part of the ieee functions
    // so there is no need to worry about that option.
    //
    SYSTEM_INFO info;
    unsigned int x64;

    GetNativeSystemInfo( &info );
    //
    // play it safe and assume that any architecture which is NOT
    // x86 is a 64-bit one that does not permit setting precision.
    //
    x64 = info.dwOemId != PROCESSOR_ARCHITECTURE_INTEL;

    if (! x64)
    {
	    switch(precision)
        {
        case GSL_IEEE_SINGLE_PRECISION:		pmode |= _PC_24; break;
        case GSL_IEEE_EXTENDED_PRECISION:	pmode |= _PC_64; break;
        case GSL_IEEE_DOUBLE_PRECISION:
        default:							pmode |= _PC_53;
	    }

        mask |= _MCW_PC;
    }

	switch(rounding)
    {
    case GSL_IEEE_ROUND_DOWN:			mode |= _RC_DOWN; break;
    case GSL_IEEE_ROUND_UP:				mode |= _RC_UP;   break;
    case GSL_IEEE_ROUND_TO_ZERO:		mode |= _RC_CHOP; break;
    case GSL_IEEE_ROUND_TO_NEAREST:
    default:							mode |= _RC_NEAR;
    }

	if(exception_mask & GSL_IEEE_MASK_INVALID)
		mode |= _EM_INVALID;
	
    if(exception_mask & GSL_IEEE_MASK_DENORMALIZED)
		mode |= _EM_DENORMAL;
	
    if(exception_mask & GSL_IEEE_MASK_DIVISION_BY_ZERO)
		mode |= _EM_ZERODIVIDE;
	
    if(exception_mask & GSL_IEEE_MASK_OVERFLOW)
		mode |= _EM_OVERFLOW;
	
    if(exception_mask & GSL_IEEE_MASK_UNDERFLOW)
		mode |= _EM_UNDERFLOW;

	if(exception_mask & GSL_IEEE_TRAP_INEXACT)
		mode &= ~_EM_INEXACT;
	else
		mode |= _EM_INEXACT;

    _controlfp_s( &currentMode, 0, 0 );

	_controlfp_s( &currentMode, mode, mask );

	return GSL_SUCCESS;
}
