module easyd.gtk.widgets;

// (C) 2014-2019 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

import easyd.base;
import easyd.gtk.base;

import core.vararg;

import gtk.Button;
import gtk.Entry;
import gtk.EditableIF;
import gtk.SpinButton;
import gtk.CheckButton;
import gtk.ScrolledWindow;
import gtk.TreeView;
import gtk.TreeIter;
import gtk.TreeViewColumn;
import gtk.TreePath;
import gtk.Widget;
import gtk.CellRenderer;
import gtk.CellRendererText;
import gtk.TreeStore;
import gdk.Pixbuf;

class Button : gtk.Button.Button
{
    void delegate()[] onClick;

    this(string s, void delegate() onclick=null)
    {
        super(s);
        addOnClicked(&onClickFunc);
        if(onclick !is null)
        {
            onClick ~= onclick;
        }
    }

    this(StockID id, void delegate() onclick=null)
    {
        super(id);
        addOnClicked(&onClickFunc);
        if(onclick !is null)
        {
            onClick ~= onclick;
        }
    }

    protected void onClickFunc(gtk.Button.Button b)
    {
        onClick.trigger();
    }
}

class LineEdit : Entry, IBindable!string
{
    void delegate(string)[] onChange;
	void delegate()[] onPressEnter;

    this()
    {
        super();
        addOnChanged(&onChangeFunc);
		addOnActivate(&onPressEnterFunc);
    }

    protected void onChangeFunc(EditableIF e)
    {
        onChange.trigger((cast(Entry)e).getText());
    }

	protected void onPressEnterFunc(Entry e)
	{
		onPressEnter.trigger;
	}

	@property string value()
	{
		return getText;
	}
	alias value this;

	@property void value(string val)
	{
		setText(val);
	}
}

class SpinBox(T) : gtk.SpinButton.SpinButton, IBindable!T
{
	this(real min=0, real max=100, real step=1)
	{
		super(min,max,step);
	}

	@property T value()
	{
		return getValue.to!T;
	}
	alias value this;
	
	@property void value(T val)
	{
		setValue(val);
	}
}

class CheckBox : gtk.CheckButton.CheckButton, IBindable!bool
{
	this(string label="")
	{
		super(label);
	}

	@property bool value()
	{
		return getActive;
	}
	alias value this;
	
	@property void value(bool val)
	{
		setActive(val);
	}
}

class TreeView : ScrolledWindow
{
    gtk.TreeView.TreeView treeView;
    alias treeView this;
	bool expandOnClick=true;
	void delegate(TreeIter)[] onChangeCursor;
	void delegate(TreeIter)[] onActivateRow;
	protected int handleChangeCursor=1;

    this()
    {
        super();
        treeView = new gtk.TreeView.TreeView();
        add(treeView);
		treeView.addOnCursorChanged(&onCursorChangeFunc);
		treeView.addOnRowActivated(&onRowActivatedFunc);
		treeView.addOnButtonRelease(&onButtonReleaseFunc);
    }

    TreeViewColumn addCol(string name)
    {
        auto col = new TreeViewColumn;
        appendColumn(col);
        col.setTitle(name);
        setHeadersVisible(getNColumns>1);
        return col;
    }

    TreeViewColumn addTextCol(string name, int modelcol)
    {
        auto col = addCol(name);
        col.add!CellRendererText("text",modelcol);
        return col;
    }

    TreeIter addRow(...)
    {
        //writeln("addRow...");
        int x;
        TreeIter it;
        if(_arguments[0] == typeid(TreeIter))
        {
            it = (cast(TreeStore)getModel).createIter(va_arg!(TreeIter)(_argptr));
            x = 1;
        }
        else
        {
            //writeln("Creating columns...");
            if(getNColumns==0)
            {
                for (int col=0; col < _arguments.length; col++)
                {
                    if (_arguments[col] == typeid(string))
                    {
                        addTextCol("",col);
                    }
                    else
                    {
                        throw new Exception("Can't auto-create view columns for a model that contains other types than strings");
                    }
                }
            }
            //writeln("Creating model...");
            if(getModel() is null)
            {
                GType[] types;
                for (int col=0; col < _arguments.length; col++)
                {
                    if (_arguments[col] == typeid(int))
                    {
                        types ~= GType.INT;
                    }
                    if (_arguments[col] == typeid(string))
                    {
                        types ~= GType.STRING;
                    }
                    if (_arguments[col] == typeid(Pixbuf))
                    {
                        types ~= Pixbuf.getType;
                    }
                }
                setModel(new TreeStore(types));
            }
            //writeln("Getting iterator...");
            it = (cast(TreeStore)getModel).createIter();
            x = 0;
        }
        //writeln("Setting values...");
        for (int col=0; x < _arguments.length; x++,col++)
        {
            if (_arguments[x] == typeid(int))
            {
                (cast(TreeStore)getModel).setValue(it,col,va_arg!(int)(_argptr));
            }
            if (_arguments[x] == typeid(string))
            {
                (cast(TreeStore)getModel).setValue(it,col,va_arg!(string)(_argptr));
            }
            if (_arguments[x] == typeid(Pixbuf))
            {
                (cast(TreeStore)getModel).setValue(it,col,va_arg!(Pixbuf)(_argptr)); 
            }
        }
        //writeln("...finished addRow");
        return it;
    }
    
    void delRow(TreeIter it)
    {
		(cast(TreeStore)getModel).remove(it);
	}

    void clear()
    {
        if(getModel() !is null)
        {
			handleChangeCursor--;
			(cast(TreeStore)getModel).clear;
			handleChangeCursor++;
			//GC.collect;
        }
    }

    void setSelectedIter(TreeIter it, int col=0)
    {
        treeView.setCursor(it.getTreePath,getColumn(col),0);
    }

	/*Guid id(TreeIter it, int col=1)
	{
		if(it is null) return Guid.invalid;
		//writeln(getModel.getValueString(it,col));
		return Guid(BigInt("0x" ~ getModel.getValueString(it,col)));
	}*/

	TreeIter currentIter()
	{
		TreePath p;
		TreeViewColumn c;
		getCursor(p,c);
		if(p)
		{
			return new TreeIter(getModel(),p);
		}else{
			return null;
		}
	}

	/*Guid currentId(int col=1)
	{
		return id(currentIter,col);
	}*/

    protected void onCursorChangeFunc(gtk.TreeView.TreeView tv)
    {
		if(handleChangeCursor<1) return;
        TreePath p;
        TreeViewColumn c;
        getCursor(p,c);
        //writeln(p);
		if(p)
		{
			onChangeCursor.trigger(new TreeIter(getModel(),p));
			handleChangeCursor--;
			treeView.setCursor(p,c,false);
			handleChangeCursor++;
		}
    }

	protected void onRowActivatedFunc(TreePath p, TreeViewColumn c, gtk.TreeView.TreeView tv)
	{
		onActivateRow.trigger(new TreeIter(getModel(),p));
		treeView.setCursor(p,c,false);
	}
	
	protected bool onButtonReleaseFunc(GdkEventButton* e, Widget w)
	{
		//writeln("Release ",e.button);
		if(e.button==1 && expandOnClick)
		{
			TreePath p;
			TreeViewColumn c;
			getCursor(p,c);
			expandRow(p,false);
		}
		return false;
	}
}

CellRenderer add(TRend)(TreeViewColumn col, ...)
{
    auto rend = new TRend;
    col.packStart(rend,0);
    for (int x=0; x < _arguments.length; x+=2)
    {
        col.addAttribute(rend,va_arg!(string)(_argptr),va_arg!(int)(_argptr));
    }
    return rend;
}

