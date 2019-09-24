module easyd.gtk.dialogs;

// (C) 2014-2019 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

import easyd.string;
import easyd.gtk.base;
import easyd.gtk.widgets;
import std.string;

import gtk.Dialog;
import gtk.Window;
import gtk.Label;
import gtk.CheckButton;
import gtk.ToggleButton;
import gtk.FileChooserDialog;
import gtk.FileFilter;

struct Dialog
{
	BindingSet bindings;
	gtk.Dialog.Dialog gtkDlg;
	GridLayout layout;
	int row = 0;

	this(Window parent, string title="", string[] buttonsText = ["OK"/*.tr*/,"Cancel"/*.tr*/], int[] responses = [1,2])
	{
		gtkDlg = new gtk.Dialog.Dialog(title, parent, DialogFlags.MODAL | DialogFlags.DESTROY_WITH_PARENT, buttonsText, cast(GtkResponseType[]) responses);
		layout = new GridLayout;
		layout.margin = 5;
		layout.spacing=5;
		gtkDlg.getContentArea.packEnd(layout,true,true,0);
	}

	~this()
	{
		if(gtkDlg !is null) gtkDlg.destroy();
	}

	T add(T)(T widget)
	{
		widget.setHexpand(1);
		layout.attach(widget,0,row++,2,1);
		return widget;
	}

	void add(string label)
	{
		auto l = new Label(label);
		l.setAlignment(0,0.5);
		layout.attach(l,0,row++,2,1);
	}
	
	T add(T)(string label, T widget)
	{
		auto l = new Label(label);
		l.setAlignment(0,0.5);
		layout.attach(l,0,row++,1,1);
		return layout.addRightOf(l,widget,1,1,true);
	}
	
	void add(T,TData)(ref TData data, string label, T widget)
	{
		bindings.add(data,add(label,widget));
	}
	
	int run(int okId=1)
	{
		bindings.load;
		gtkDlg.showAll;
		int result = cast(int)(gtkDlg.run);
		gtkDlg.hide;
		if(result==okId) bindings.apply;
		return result;
	}

	void return1()
	{
		gtkDlg.response(cast(GtkResponseType)1);
	}
}

void showMessage(Window parent, string s, MessageType t = MessageType.INFO)
{
	showMessage(parent,"",s,t);
}

void showMessage(Window parent, string title, string s, MessageType t = MessageType.INFO)
{
	auto d = Dialog(parent,title,[t==MessageType.ERROR? "Close"/*.tr*/ : "OK"/*.tr*/],[1]);
	d.add(s);
	if(title.length>0) d.gtkDlg.setDefaultSize(200,1);
	d.run;
}

bool confirm(Window parent, string question)
{
	return confirm(parent,"",question);
}

bool confirm(Window parent, string title, string question)
{
	auto d = Dialog(parent,title,["Yes"/*.tr*/,"No"/*.tr*/],[1,2]);
	d.add(question);
	return d.run==1;
}

bool stringDlg(Window parent, out string result, string title="", string text="", bool password=false)
{
	auto d = new Dialog(parent,title);
	
	if(text.length>0) d.add(text);
	
	auto l = new LineEdit;
	l.onPressEnter ~= &d.return1;
	d.add(l);
	
	if(password)
	{
		l.setVisibility(false);
		struct StringDlgController
		{
			CheckButton cb;
			this(LineEdit l)
			{
				cb = new CheckButton("Show password"/*.tr*/);
				cb.addOnToggled(&cbClick);
			}
			void cbClick(ToggleButton t)
			{
				l.setVisibility(cb.getActive);
			}
		}
		auto c=StringDlgController(l);
		d.add(c.cb);
	}
	
	if(d.run==1)
	{
		result = l.getText;
		return true;
	}
	else
	{
		return false;
	}
}

bool fileDlg(Window parent, ref string result, string filters="*", FileChooserAction action=FileChooserAction.OPEN)
{
	auto fc= new FileChooserDialog("", parent, action);

	auto fl = filters.split;
	if(action==FileChooserAction.OPEN)
	{
		auto ff = new FileFilter;
		ff.setName(filters);
		foreach(f;fl)
		{
			ff.addPattern(f);
		}
		fc.addFilter(ff);
	}
	else
	{
		foreach(f;fl)
		{
			auto ff = new FileFilter;
			ff.setName(f);
			ff.addPattern(f);
			fc.addFilter(ff);
		}
	}

	fc.selectFilename(result);

	bool ok = fc.run() == ResponseType.OK;
	if (ok) 
	{
		result = fc.getFilename;
		string f = fc.getFilter.getName;
		if(f.startsWith("*") && f.countChar('*')==1 && !result.endsWith(f.subStr(1))) result ~= f.subStr(1);
	}
	fc.destroy();
	return ok;
}
