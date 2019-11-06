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

methodmap DynamicOffset
{
	public DynamicOffset(int index, int cell)
	{
		return view_as<DynamicOffset>(index << 16 | cell); 
	}
	
	property int Index
	{
		public get()
		{
			return view_as<int>(this) >>> 16;
		}
	}
	
	property int Cell
	{
		public get()
		{
			return view_as<int>(this) & 0xFFFF; 
		}
	}
	
	public DynamicOffset Clone(int blocksize, int addcells)
	{
		if (addcells ==  0)
		{
			return this;
		}
		
		int index = this.Index;
		int cell = this.Cell + addcells;
		
		while (cell >= blocksize)
		{
			index++;
			cell-=blocksize;
		}
		
		return DynamicOffset(index, cell);
	}
}