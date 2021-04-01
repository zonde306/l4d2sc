/**
 * =============================================================================
 * Dynamic for SourceMod (C)2016 Matthew J Dunn.   All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

#if defined _dynamic_included
  #endinput
#endif
#define _dynamic_included

#define INVALID_DYNAMIC_OBJECT			view_as<Dynamic>(-1)
#define Invalid_Dynamic_Object			-1
#define INVALID_DYNAMIC_OFFSET			view_as<DynamicOffset>(-1)
#define INVALID_DYNAMIC_INDEX			-1
#define DYNAMIC_MEMBERNAME_MAXLEN		64

enum Dynamic_MemberType
{
	DynamicType_Int = 0,
	DynamicType_Float = 1,
	DynamicType_String = 2,
	DynamicType_Object = 3,
	DynamicType_Dynamic = 3,
	DynamicType_Bool = 4,
	DynamicType_Handle = 5,
	DynamicType_Vector = 6,
	DynamicType_Unknown = 7
}

enum Dynamic_Operator
{
	DynamicOperator_Equals=0,
	DynamicOperator_NotEquals,
}

typeset Dynamic_HookType
{
	// HookChanges
	function void (Dynamic obj, DynamicOffset offset, const char[] member, Dynamic_MemberType type);
	
	// DynamicReadKeyValue
	function Action (Dynamic obj, const char[] member, int depth);
}

#include <dynamic/natives>
#include <dynamic/methodmaps/dynamicoffset>
#include <dynamic/methodmaps/dynamic>
#include <dynamic/methodmaps/collection>
#include <dynamic/methodmaps/basic>

public SharedPlugin __pl_dynamic = 
{
	name = "dynamic",
	file = "dynamic.smx",
	#if defined REQUIRE_PLUGIN
		required = 1,
	#else
		required = 0,
	#endif
};
