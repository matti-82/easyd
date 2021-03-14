module easyd.gtk.base;

// (C) 2014-2019 by Matthias Rossmy
// This file is distributed under the "Fair Use License v2"

//TODO: .tr wieder einkommentieren, sobald die Funktion portiert wurde

/* Example:
mixin GuiApp!(TestWin);

class TestWin : ILayoutWindow
{
    void init()
    {
        title="GtkTest";
    }
}
*/

import easyd.base;
import std.conv;
import std.stdio;

public import gtk.Main;
import gtk.Clipboard;
import gtk.Grid;
import gtk.Box;
import gtk.Widget;
import gtk.MainWindow;
import gtk.MenuBar;
import gtk.Menu;
import gtk.ImageMenuItem;
import gtk.SeparatorMenuItem;
import gtk.AccelGroup;
import gdk.Atom;
import gdk.Event;
import gobject.ObjectG;

mixin template GuiApp(T)
{
	T gMainWin;

	void main(string[] args)
	{
		Main.init(args);
		gMainWin = new T();
		Main.run();
	}
}

void handleGtkEvents(bool sleep=false, bool dbg=false)
{
	bool eventsProcessed=false;
	while(Main.eventsPending)
	{
		Main.iteration;
		eventsProcessed=true;
	}
	if(dbg) writeln(eventsProcessed?"Events processed":"No events");
    if(sleep) sleepMsec(1);
}

Clipboard clipBoard(string name="CLIPBOARD")
{
	return Clipboard.get(intern(name, true));
}

class GridLayout : Grid
{
    protected Widget lastWidget = null;
    protected bool hasColStretch = false;
    protected bool hasRowStretch = false;

    @property void spacing(int value)
    {
        setRowSpacing(value);
        setColumnSpacing(value);
    }

    @property void margin(int value)
    {
        setMarginLeft(value);
        setMarginRight(value);
        setMarginTop(value);
        setMarginBottom(value);
    }

    T add(T)(T widget, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false, int width=0, int height=0)
    {
        if(getOrientation()==GtkOrientation.HORIZONTAL)
        {
            return addRight(widget, colspan, rowspan, colstretch, rowstretch, width, height);
        }
        else
        {
            return addBelow(widget, colspan, rowspan, colstretch, rowstretch, width, height);
        }
    }

    T addBelow(T)(T widget, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false, int width=0, int height=0)
    {
        return addBelow(lastWidget,widget,colspan,rowspan,colstretch,rowstretch,width,height);
    }

    T addAbove(T)(T widget, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false, int width=0, int height=0)
    {
        return addAbove(lastWidget,widget,colspan,rowspan,colstretch,rowstretch,width,height);
    }

    T addLeft(T)(T widget, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false, int width=0, int height=0)
    {
        return addLeftOf(lastWidget,widget,colspan,rowspan,colstretch,rowstretch,width,height);
    }

    T addRight(T)(T widget, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false, int width=0, int height=0)
    {
        return addRightOf(lastWidget,widget,colspan,rowspan,colstretch,rowstretch,width,height);
    }

    T addBelow(T)(Widget reference, T widget, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false, int width=0, int height=0)
    {
        setupWidget(widget,colstretch,rowstretch,width,height);
        attachNextTo(widget,reference,GtkPositionType.BOTTOM,colspan,rowspan);
        lastWidget = widget;
        return widget;
    }

    T addAbove(T)(Widget reference, T widget, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false, int width=0, int height=0)
    {
        setupWidget(widget,colstretch,rowstretch,width,height);
        attachNextTo(widget,reference,GtkPositionType.TOP,colspan,rowspan);
        lastWidget = widget;
        return widget;
    }

    T addLeftOf(T)(Widget reference, T widget, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false, int width=0, int height=0)
    {
        setupWidget(widget,colstretch,rowstretch,width,height);
        attachNextTo(widget,reference,GtkPositionType.LEFT,colspan,rowspan);
        lastWidget = widget;
        return widget;
    }

    T addRightOf(T)(Widget reference, T widget, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false, int width=0, int height=0)
    {
        setupWidget(widget,colstretch,rowstretch,width,height);
        attachNextTo(widget,reference,GtkPositionType.RIGHT,colspan,rowspan);
        lastWidget = widget;
        return widget;
    }

    typeof(this) addSubLayout(int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false)
    {
        if(getOrientation()==GtkOrientation.HORIZONTAL)
        {
            return addSubLayoutRight(colspan, rowspan, colstretch, rowstretch);
        }
        else
        {
            return addSubLayoutBelow(colspan, rowspan, colstretch, rowstretch);
        }
    }

    typeof(this) addSubLayoutBelow(int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false)
    {
        return addSubLayoutBelow(lastWidget, colspan, rowspan, colstretch, rowstretch);
    }

    typeof(this) addSubLayoutAbove(int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false)
    {
        return addSubLayoutAbove(lastWidget, colspan, rowspan, colstretch, rowstretch);
    }

    typeof(this) addSubLayoutLeft(int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false)
    {
        return addSubLayoutLeftOf(lastWidget, colspan, rowspan, colstretch, rowstretch);
    }

    typeof(this) addSubLayoutRight(int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false)
    {
        return addSubLayoutRightOf(lastWidget, colspan, rowspan, colstretch, rowstretch);
    }

    typeof(this) addSubLayoutBelow(Widget reference, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false)
    {
        auto widget = createSubLayout(colstretch, rowstretch);
        attachNextTo(widget,reference,GtkPositionType.BOTTOM,colspan,rowspan);
        lastWidget = widget;
        return widget;
    }

    typeof(this) addSubLayoutAbove(Widget reference, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false)
    {
        auto widget = createSubLayout(colstretch, rowstretch);
        attachNextTo(widget,reference,GtkPositionType.TOP,colspan,rowspan);
        lastWidget = widget;
        return widget;
    }

    typeof(this) addSubLayoutLeftOf(Widget reference, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false)
    {
        auto widget = createSubLayout(colstretch, rowstretch);
        attachNextTo(widget,reference,GtkPositionType.LEFT,colspan,rowspan);
        lastWidget = widget;
        return widget;
    }

    typeof(this) addSubLayoutRightOf(Widget reference, int colspan=1, int rowspan=1, bool colstretch=false, bool rowstretch=false)
    {
        auto widget = createSubLayout(colstretch, rowstretch);
        attachNextTo(widget,reference,GtkPositionType.RIGHT,colspan,rowspan);
        lastWidget = widget;
        return widget;
    }

    void autoStretch()
    {
        auto children = getChildren();
        for(;children !is null;children=children.next)
        {
            Widget w = ObjectG.getDObject!(Widget)(cast(GtkWidget*) children.data);
            if(typeid(w).to!string == typeid(this).to!string)
            {
                (cast(typeof(this)) w).autoStretch();
            }
            else
            {
                if(!hasColStretch) w.setHexpand(1);
                if(!hasRowStretch) w.setVexpand(1);
            }
        }
    }

    protected void setupWidget(T)(T widget, bool colstretch, bool rowstretch, int width, int height)
    {
        if(width>0 || height>0)
        {
            widget.setSizeRequest(width,height);
        }
        if(colstretch)
        {
            widget.setHexpand(1);
            hasColStretch = true;
        }
        if(rowstretch)
        {
            widget.setVexpand(1);
            hasRowStretch = true;
        }
    }

    typeof(this) createSubLayout(bool colstretch, bool rowstretch)
    {
        auto l = new typeof(this);
        l.spacing = getRowSpacing;
        if(!colstretch) l.hasColStretch = true;
        if(!rowstretch) l.hasRowStretch = true;
        return l;
    }
}

interface IInit
{
    void init();
}

abstract class ILayoutWindow : MainWindow, IInit
{
    public GridLayout layout;
    public bool autoStretchAfterInit = true;
    void delegate()[] onClose;
    protected MenuBar topMenuBarIntern;
    protected MenuBar bottomMenuBarIntern;
    public AccelGroup accelGroup;
    protected Box vBox;

    public MenuBar topMenuBar()
    {
        return topMenuBarIntern.create;
    }

    public MenuBar bottomMenuBar()
    {
        return bottomMenuBarIntern.create;
    }

    this(int minWidth=200, int minHeight=30)
    {
        super("");
        setDefaultSize(minWidth,minHeight);
        setPosition(WindowPosition.CENTER);

        layout = new GridLayout();
        layout.margin = 5;
        layout.spacing = 5;

        init();

        vBox = new Box(Orientation.VERTICAL,0);
        add(vBox);
        if(topMenuBarIntern !is null) vBox.add(topMenuBarIntern);
        vBox.add(layout);
        if(bottomMenuBarIntern !is null) vBox.add(bottomMenuBarIntern);

        if(autoStretchAfterInit) layout.autoStretch();

        addOnDelete(&onCloseFunc);

        showAll();
    }

    protected bool onCloseFunc(Event e, Widget w)
    {
        onClose.trigger();
        return false;
    }

    @property void title(string value)
    {
        setTitle(value);
    }
}

interface IBindable(T)
{
	T value();
	void value(T val);
}

abstract class IBinding
{
	void delegate()[] onEdit;
	void load();
	void apply();
}

class Binding(T) : IBinding
{
	T* data;
	IBindable!T control;
	string oldValue;

	override void load()
	{
		control.value = *data;
		oldValue = control.value.to!string; //TODO: to!string durch String-Serialisierung ersetzen (damit Binding auch strukturierte Datentypen unterstützt)
	}
	
	override void apply()
	{
		string newvalue = control.value.to!string; //TODO: to!string durch String-Serialisierung ersetzen
		if(newvalue != oldValue) //strings vergleichen, weil der Vergleich von 2 gleichen class-Objekten trotzdem ungleich zurückgeben kann
		{
			*data = control.value;
			static if(__traits(hasMember, T, "update")) (*data).update;
			onEdit.trigger;
			oldValue = newvalue;
		}
	}
}

struct BindingSet
{
	IBinding[] bindings;
	alias bindings this;

	void add(T)(T* data, IBindable!T control)
	{
		auto b = new Binding!T;
		b.data=data;
		b.control=control;
		bindings ~= b;
	}

	void add(T)(ref T data, IBindable!T control)
	{
		add(&data,control);
	}

	void load()
	{
		foreach(b;bindings) b.load;
	}

	void apply()
	{
		foreach(b;bindings) b.apply;
	}
}

class MenuItem : ImageMenuItem
{
    Menu subMenuIntern;
    void delegate()[] onClick;

    this(string s, void delegate() onclick=null)
    {
        super(s);
        setupEvents(onclick);
    }

    this(StockID id, void delegate() onclick=null)
    {
        super(id,null);
        setupEvents(onclick);
    }

    this(string s, StockID id, void delegate() onclick=null)
    {
        super(id,null);
        setLabel(s);
        setupEvents(onclick);
    }

    this(Widget w, void delegate() onclick=null)
    {
        super();
        setImage(w);
        setupEvents(onclick);
    }

    Menu subMenu()
    {
        if(subMenuIntern is null)
        {
            subMenuIntern = new Menu();
            setSubmenu(subMenuIntern);
        }
        return subMenuIntern;
    }

    MenuItem add(string s, void delegate() onclick=null)
    {
        auto item = new MenuItem(s,onclick);
        subMenu.append(item);
        return item;
    }

    MenuItem add(StockID id, void delegate() onclick=null)
    {
        auto item = new MenuItem(id,onclick);
        subMenu.append(item);
        return item;
    }

    MenuItem add(string s, StockID id, void delegate() onclick=null)
    {
        auto item = new MenuItem(s,id,onclick);
        subMenu.append(item);
        return item;
    }

    MenuItem addWidget(Widget w, void delegate() onclick=null)
    {
        auto item = new MenuItem(w,onclick);
        subMenu.append(item);
        return item;
    }

	void addSeparator()
	{
		subMenu.append(new SeparatorMenuItem);
	}

	void addAccel(ILayoutWindow win, string shortcut)
    {
        uint accelKey;
        GdkModifierType accelMods;
        AccelGroup.acceleratorParse(shortcut,accelKey,accelMods);
        addAccelerator("activate",win.accelGroup,accelKey,accelMods,GtkAccelFlags.VISIBLE);
    }

    protected void setupEvents(void delegate() onclick)
    {
        addOnActivate(&onClickFunc);
        //addOnButtonPress(&onPressFunc);
        if(onclick !is null)
        {
            onClick ~= onclick;
        }
    }

    /*protected bool onPressFunc(Event event, Widget widget)
    {
        onClick.trigger();
        return onClick.length>0;
    }*/

    protected void onClickFunc(gtk.MenuItem.MenuItem item)
    {
        onClick.trigger();
    }
}

mixin template MenuAdd()
{
    MenuItem add(string s, void delegate() onclick=null)
    {
        auto item = new MenuItem(s,onclick);
        append(item);
        return item;
    }

    MenuItem add(StockID id, void delegate() onclick=null)
    {
        auto item = new MenuItem(id,onclick);
        append(item);
        return item;
    }

    MenuItem add(string s, StockID id, void delegate() onclick=null)
    {
        auto item = new MenuItem(s,id,onclick);
        append(item);
        return item;
    }

    MenuItem addWidget(Widget w, void delegate() onclick=null)
    {
        auto item = new MenuItem(w,onclick);
        append(item);
        return item;
    }
}

class Menu : gtk.Menu.Menu
{
    mixin MenuAdd;
}

class MenuBar : gtk.MenuBar.MenuBar
{
    mixin MenuAdd;
}

