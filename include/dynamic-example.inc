#if defined _dynamic_class_myclass_
  #endinput
#endif
#define _dynamic_class_myclass_

methodmap MyClass < Dynamic
{
	public MyClass()
	{
		// First we make a new dymanic object
		Dynamic myclass = Dynamic(64, 0);

		// Next we will define all the members
		// -> We do this to force the offsets to always be in the same location
		//    over multiple instances of the same class.
		myclass.SetInt("SomeInt", 0);
		myclass.SetFloat("SomeFloat", 0.0);
		myclass.SetBool("SomeBool", false);
		myclass.SetString("SomeString", "", 64);
		myclass.SetHandle("SomeHandle", null);
		myclass.SetObject("SomeObject", view_as<Dynamic>(INVALID_DYNAMIC_OBJECT));
		myclass.SetVector("SomeVector", NULL_VECTOR);
		return view_as<MyClass>(myclass);
	}

	// Note that I use static offsets to access members.
	// -> This improves performance by caching member offsets
	// -> This is why we force the members in during the contructor
	// -> Failure to force members in the constructor will cause corruption

	property int SomeInt
	{
		public get()
		{
			static int offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("SomeInt");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetIntByOffset(offset);
		}
		public set(int value)
		{
			static int offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("SomeInt");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetInt("SomeInt", value);
					return;
				}
			}
			this.SetIntByOffset(offset, value);
		}
	}

	property float SomeFloat
	{
		public get()
		{
			static int offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("SomeFloat");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetFloatByOffset(offset);
		}
		public set(float value)
		{
			static int offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("SomeFloat");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetFloat("SomeFloat", value);
					return;
				}
			}
			this.SetFloatByOffset(offset, value);
		}
	}

	property bool SomeBool
	{
		public get()
		{
			static int offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("SomeBool");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBoolByOffset(offset);
		}
		public set(bool value)
		{
			static int offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("SomeBool");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetBool("SomeBool", value);
					return;
				}
			}
			this.SetBoolByOffset(offset, value);
		}
	}

	public bool GetSomeString(char[] buffer, int length)
	{
		static int offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("SomeString");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetStringByOffset(offset, buffer, length);
		return true;
	}

	public void SetSomeString(const char[] buffer)
	{
		static int offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("SomeString");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.SetString("SomeString", buffer);
				return;
			}
		}
		this.SetStringByOffset(offset, buffer);
	}

	property Handle SomeHandle
	{
		public get()
		{
			static int offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("SomeHandle");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetHandleByOffset(offset);
		}
		public set(Handle value)
		{
			static int offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("SomeHandle");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetHandle("SomeHandle", value);
					return;
				}
			}
			this.SetHandleByOffset(offset, value);
		}
	}

	property Dynamic SomeObject
	{
		public get()
		{
			static int offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("SomeObject");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetObjectByOffset(offset);
		}
		public set(Dynamic value)
		{
			static int offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("SomeObject");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetObject("SomeObject", value);
					return;
				}
			}
			this.SetObjectByOffset(offset, value);
		}
	}

	public bool GetSomeVector(float[3] value)
	{
		static int offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("SomeVector");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetVectorByOffset(offset, value);
		return true;
	}

	public void SetSomeVector(const float[3] value)
	{
		static int offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("SomeVector");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.SetVector("SomeVector", value);
				return;
			}
		}
		this.SetVectorByOffset(offset, value);
	}
}