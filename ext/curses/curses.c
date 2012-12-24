/*
 * ext/curses/curses.c
 * 
 * by MAEDA Shugo (ender@pic-internet.or.jp)
 * modified by Yukihiro Matsumoto (matz@ruby.club.or.jp)
 */

#ifdef HAVE_NCURSES_H
# include <ncurses.h>
#else
# ifdef HAVE_NCURSES_CURSES_H
#  include <ncurses/curses.h>
# else
#  include <curses.h>
#  if defined(__NetBSD__) && !defined(_maxx)
#   define _maxx maxx
#  endif
#  if defined(__NetBSD__) && !defined(_maxy)
#   define _maxy maxy
#  endif
# endif
#endif

#include "ruby.h"

static VALUE mCurses;
static VALUE cWindow;

VALUE rb_stdscr;

struct windata {
    WINDOW *window;
};

#define NUM2CHAR(x) (char)NUM2INT(x)
#define CHAR2FIX(x) INT2FIX((int)x)

static void
no_window()
{
    Fail("already closed window");
}

#define GetWINDOW(obj, winp) {\
    Data_Get_Struct(obj, struct windata, winp);\
    if (winp->window == 0) no_window();\
}

static void
curses_err()
{
    Fail("curses error");
}

#define CHECK(c) if ((c)==ERR) {curses_err();}

static void
free_window(winp)
    struct windata *winp;
{
    if (winp->window && winp->window != stdscr) delwin(winp->window);
    winp->window = 0;
}

static VALUE
prep_window(class, window)
    VALUE class;
    WINDOW *window;
{
    VALUE obj;
    struct windata *winp;

    if (window == NULL) {
	Fail("failed to create window");
    }

    obj = Data_Make_Struct(class, struct windata, 0, free_window, winp);
    winp->window = window;
    
    return obj;    
}

/*-------------------------- module Curses --------------------------*/

/* def init_screen */
static VALUE
curses_init_screen()
{
    initscr();
    if (stdscr == 0) {
	Fail("cannot initialize curses");
    }
    clear();
    rb_stdscr = prep_window(cWindow, stdscr);
    return Qnil;
}

/* def stdscr */
static VALUE
curses_stdscr()
{
    if (!rb_stdscr) curses_init_screen();
    return rb_stdscr;
}

/* def close_screen */
static VALUE
curses_close_screen()
{
    CHECK(endwin());
    return Qnil;
}

/* def closed? */
static VALUE
curses_closed()
{
#ifdef HAVE_ENDWIN
    if (isendwin()) {
	return TRUE;
    }
    return FALSE;
#else
    rb_notimplement();
#endif
}

/* def clear */
static VALUE
curses_clear(obj)
    VALUE obj;
{
    wclear(stdscr);
    return Qnil;
}

/* def refresh */
static VALUE
curses_refresh(obj)
    VALUE obj;
{
    CHECK(refresh());
    return Qnil;
}

/* def refresh */
static VALUE
curses_doupdate(obj)
    VALUE obj;
{
    CHECK(doupdate());
    return Qnil;
}

/* def echo */
static VALUE
curses_echo(obj)
    VALUE obj;
{
    CHECK(echo());
    return Qnil;
}

/* def noecho */
static VALUE
curses_noecho(obj)
    VALUE obj;
{
    CHECK(noecho());
    return Qnil;
}

/* def raw */
static VALUE
curses_raw(obj)
    VALUE obj;
{
    CHECK(raw());
    return Qnil;
}

/* def noraw */
static VALUE
curses_noraw(obj)
    VALUE obj;
{
    CHECK(noraw());
    return Qnil;
}

/* def cbreak */
static VALUE
curses_cbreak(obj)
    VALUE obj;
{
    CHECK(cbreak());
    return Qnil;
}

/* def nocbreak */
static VALUE
curses_nocbreak(obj)
    VALUE obj;
{
    CHECK(nocbreak());
    return Qnil;
}

/* def nl */
static VALUE
curses_nl(obj)
    VALUE obj;
{
    CHECK(nl());
    return Qnil;
}

/* def nonl */
static VALUE
curses_nonl(obj)
    VALUE obj;
{
    CHECK(nonl());
    return Qnil;
}

/* def beep */
static VALUE
curses_beep(obj)
    VALUE obj;
{
#ifdef HAVE_BEEP
    beep();
#endif
    return Qnil;
}

/* def flash */
static VALUE
curses_flash(obj)
    VALUE obj;
{
    flash();
    return Qnil;
}

/* def ungetch */
static VALUE
curses_ungetch(obj, ch)
    VALUE obj;
    VALUE ch;
{
#ifdef HAVE_UNGETCH
    CHECK(ungetch(NUM2INT(ch)));
#else
    rb_notimplement();
#endif
    return Qnil;
}

/* def setpos(y, x) */
static VALUE
curses_setpos(obj, y, x)
    VALUE obj;
    VALUE y;
    VALUE x;
{
    CHECK(move(NUM2INT(y), NUM2INT(x)));
    return Qnil;
}

/* def standout */
static VALUE
curses_standout(obj)
    VALUE obj;
{
    standout();
    return Qnil;
}

/* def standend */
static VALUE
curses_standend(obj)
    VALUE obj;
{
    standend();
    return Qnil;
}

/* def inch */
static VALUE
curses_inch(obj)
    VALUE obj;
{
    return CHAR2FIX(inch());
}

/* def addch(ch) */
static VALUE
curses_addch(obj, ch)
    VALUE obj;
    VALUE ch;
{
    CHECK(addch(NUM2CHAR(ch)));
    return Qnil;
}

/* def insch(ch) */
static VALUE
curses_insch(obj, ch)
    VALUE obj;
    VALUE ch;
{
    CHECK(insch(NUM2CHAR(ch)));
    return Qnil;
}

/* def addstr(str) */
static VALUE
curses_addstr(obj, str)
    VALUE obj;
    VALUE str;
{
    addstr(RSTRING(str)->ptr);
    return Qnil;
}

/* def getch */
static VALUE
curses_getch(obj)
    VALUE obj;
{
    return CHAR2FIX(getch());
}

/* def getstr */
static VALUE
curses_getstr(obj)
    VALUE obj;
{
    char rtn[1024]; /* This should be big enough.. I hope */
    CHECK(getstr(rtn));
    return str_taint(str_new2(rtn));
}

/* def delch */
static VALUE
curses_delch(obj)
    VALUE obj;
{
    CHECK(delch());
    return Qnil;
}

/* def delelteln */
static VALUE
curses_deleteln(obj)
    VALUE obj;
{
    CHECK(deleteln());
    return Qnil;
}

static VALUE
curses_lines()
{
    return INT2FIX(LINES);
}

static VALUE
curses_cols()
{
    return INT2FIX(COLS);
}

/*-------------------------- class Window --------------------------*/

/* def new(lines, cols, top, left) */
static VALUE
window_s_new(class, lines, cols, top, left)
    VALUE class;
    VALUE lines;
    VALUE cols;
    VALUE top;
    VALUE left;
{
    WINDOW *window;
    
    window = newwin(NUM2INT(lines), NUM2INT(cols), NUM2INT(top), NUM2INT(left));
    wclear(window);
    return prep_window(class, window);
}

/* def subwin(lines, cols, top, left) */
static VALUE
window_subwin(obj, lines, cols, top, left)
    VALUE obj;
    VALUE lines;
    VALUE cols;
    VALUE top;
    VALUE left;
{
    struct windata *winp;
    WINDOW *window;

    GetWINDOW(obj, winp);
    window = subwin(winp->window, NUM2INT(lines), NUM2INT(cols),
		                  NUM2INT(top), NUM2INT(left));
    return prep_window(cWindow, window);
}

/* def close */
static VALUE
window_close(obj)
    VALUE obj;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    free_window(winp);

    return Qnil;
}

/* def clear */
static VALUE
window_clear(obj)
    VALUE obj;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    wclear(winp->window);
    
    return Qnil;
}

/* def refresh */
static VALUE
window_refresh(obj)
    VALUE obj;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    CHECK(wrefresh(winp->window));
    
    return Qnil;
}

/* def box(vert, hor) */
static VALUE
window_box(obj, vert, hor)
    VALUE obj;
    VALUE vert;
    VALUE hor;
{
    struct windata *winp; 
   
    GetWINDOW(obj, winp);
    box(winp->window, NUM2CHAR(vert), NUM2CHAR(hor));
    
    return Qnil;
}


/* def move(y, x) */
static VALUE
window_move(obj, y, x)
    VALUE obj;
    VALUE y;
    VALUE x;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    CHECK(mvwin(winp->window, NUM2INT(y), NUM2INT(x)));

    return Qnil;
}

/* def setpos(y, x) */
static VALUE
window_setpos(obj, y, x)
    VALUE obj;
    VALUE y;
    VALUE x;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    CHECK(wmove(winp->window, NUM2INT(y), NUM2INT(x)));
    return Qnil;
}

/* def cury */
static VALUE
window_cury(obj)
    VALUE obj;
{
    struct windata *winp;
    int x, y;

    GetWINDOW(obj, winp);
    getyx(winp->window, y, x);
    return INT2FIX(y);
}

/* def curx */
static VALUE
window_curx(obj)
    VALUE obj;
{
    struct windata *winp;
    int x, y;

    GetWINDOW(obj, winp);
    getyx(winp->window, y, x);
    return INT2FIX(x);
}

/* def maxy */
static VALUE
window_maxy(obj)
    VALUE obj;
{
    struct windata *winp;
    int x, y;

    GetWINDOW(obj, winp);
#ifdef getmaxy
    return INT2FIX(getmaxy(winp->window));
#else
#ifdef getmaxyx
    getmaxyx(winp->window, y, x);
    return INT2FIX(y);
#else
    return INT2FIX(winp->window->_maxy+1);
#endif
#endif
}

/* def maxx */
static VALUE
window_maxx(obj)
    VALUE obj;
{
    struct windata *winp;
    int x, y;

    GetWINDOW(obj, winp);
#ifdef getmaxx
    return INT2FIX(getmaxx(winp->window));
#else
#ifdef getmaxyx
    getmaxyx(winp->window, y, x);
    return INT2FIX(x);
#else
    return INT2FIX(winp->window->_maxx+1);
#endif
#endif
}

/* def begy */
static VALUE
window_begy(obj)
    VALUE obj;
{
    struct windata *winp;
    int x, y;

    GetWINDOW(obj, winp);
#ifdef getbegyx
    getbegyx(winp->window, y, x);
    return INT2FIX(y);
#else
    return INT2FIX(winp->window->_begy);
#endif
}

/* def begx */
static VALUE
window_begx(obj)
    VALUE obj;
{
    struct windata *winp;
    int x, y;

    GetWINDOW(obj, winp);
#ifdef getbegyx
    getbegyx(winp->window, y, x);
    return INT2FIX(x);
#else
    return INT2FIX(winp->window->_begx);
#endif
}

/* def standout */
static VALUE
window_standout(obj)
    VALUE obj;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    wstandout(winp->window);
    return Qnil;
}

/* def standend */
static VALUE
window_standend(obj)
    VALUE obj;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    wstandend(winp->window);
    return Qnil;
}

/* def inch */
static VALUE
window_inch(obj)
    VALUE obj;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    return CHAR2FIX(winch(winp->window));
}

/* def addch(ch) */
static VALUE
window_addch(obj, ch)
    VALUE obj;
    VALUE ch;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    CHECK(waddch(winp->window, NUM2CHAR(ch)));
    
    return Qnil;
}

/* def insch(ch) */
static VALUE
window_insch(obj, ch)
    VALUE obj;
    VALUE ch;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    CHECK(winsch(winp->window, NUM2CHAR(ch)));
    
    return Qnil;
}

/* def addstr(str) */
static VALUE
window_addstr(obj, str)
    VALUE obj;
    VALUE str;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    CHECK(waddstr(winp->window, RSTRING(str)->ptr));
    
    return Qnil;
}

/* def <<(str) */
static VALUE
window_addstr2(obj, str)
    VALUE obj;
    VALUE str;
{
    window_addstr(obj, str);
    return obj;
}

/* def getch */
static VALUE
window_getch(obj)
    VALUE obj;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    return CHAR2FIX(wgetch(winp->window));
}

/* def getstr */
static VALUE
window_getstr(obj)
    VALUE obj;
{
    struct windata *winp;
    char rtn[1024]; /* This should be big enough.. I hope */
    
    GetWINDOW(obj, winp);
    CHECK(wgetstr(winp->window, rtn));
    return str_taint(str_new2(rtn));
}

/* def delch */
static VALUE
window_delch(obj)
    VALUE obj;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    CHECK(wdelch(winp->window));
    return Qnil;
}

/* def delelteln */
static VALUE
window_deleteln(obj)
    VALUE obj;
{
    struct windata *winp;
    
    GetWINDOW(obj, winp);
    CHECK(wdeleteln(winp->window));
    return Qnil;
}

/*------------------------- Initialization -------------------------*/
void
Init_curses()
{
    mCurses = rb_define_module("Curses");
    rb_define_module_function(mCurses, "init_screen", curses_init_screen, 0);
    rb_define_module_function(mCurses, "close_screen", curses_close_screen, 0);
    rb_define_module_function(mCurses, "closed?", curses_closed, 0);
    rb_define_module_function(mCurses, "stdscr", curses_stdscr, 0);
    rb_define_module_function(mCurses, "refresh", curses_refresh, 0);
    rb_define_module_function(mCurses, "doupdate", curses_doupdate, 0);
    rb_define_module_function(mCurses, "clear", curses_clear, 0);
    rb_define_module_function(mCurses, "echo", curses_echo, 0);
    rb_define_module_function(mCurses, "noecho", curses_noecho, 0);
    rb_define_module_function(mCurses, "raw", curses_raw, 0);
    rb_define_module_function(mCurses, "noraw", curses_noraw, 0);
    rb_define_module_function(mCurses, "cbreak", curses_cbreak, 0);
    rb_define_module_function(mCurses, "nocbreak", curses_nocbreak, 0);
    rb_define_alias(mCurses, "crmode", "cbreak");
    rb_define_alias(mCurses, "nocrmode", "nocbreak");
    rb_define_module_function(mCurses, "nl", curses_nl, 0);
    rb_define_module_function(mCurses, "nonl", curses_nonl, 0);
    rb_define_module_function(mCurses, "beep", curses_beep, 0);
    rb_define_module_function(mCurses, "flash", curses_flash, 0);
    rb_define_module_function(mCurses, "ungetch", curses_ungetch, 1);
    rb_define_module_function(mCurses, "setpos", curses_setpos, 2);
    rb_define_module_function(mCurses, "standout", curses_standout, 0);
    rb_define_module_function(mCurses, "standend", curses_standend, 0);
    rb_define_module_function(mCurses, "inch", curses_inch, 0);
    rb_define_module_function(mCurses, "addch", curses_addch, 1);
    rb_define_module_function(mCurses, "insch", curses_insch, 1);
    rb_define_module_function(mCurses, "addstr", curses_addstr, 1);
    rb_define_module_function(mCurses, "getch", curses_getch, 0);
    rb_define_module_function(mCurses, "getstr", curses_getstr, 0);
    rb_define_module_function(mCurses, "delch", curses_delch, 0);
    rb_define_module_function(mCurses, "deleteln", curses_deleteln, 0);
    rb_define_module_function(mCurses, "lines", curses_lines, 0);
    rb_define_module_function(mCurses, "cols", curses_cols, 0);
    
    cWindow = rb_define_class_under(mCurses, "Window", cObject);
    rb_define_singleton_method(cWindow, "new", window_s_new, 4);
    rb_define_method(cWindow, "subwin", window_subwin, 4);
    rb_define_method(cWindow, "close", window_close, 0);
    rb_define_method(cWindow, "clear", window_clear, 0);
    rb_define_method(cWindow, "refresh", window_refresh, 0);
    rb_define_method(cWindow, "box", window_box, 2);
    rb_define_method(cWindow, "move", window_move, 2);
    rb_define_method(cWindow, "setpos", window_setpos, 2);
    rb_define_method(cWindow, "cury", window_cury, 0);
    rb_define_method(cWindow, "curx", window_curx, 0);
    rb_define_method(cWindow, "maxy", window_maxy, 0);
    rb_define_method(cWindow, "maxx", window_maxx, 0);
    rb_define_method(cWindow, "begy", window_begy, 0);
    rb_define_method(cWindow, "begx", window_begx, 0);
    rb_define_method(cWindow, "standout", window_standout, 0);
    rb_define_method(cWindow, "standend", window_standend, 0);
    rb_define_method(cWindow, "inch", window_inch, 0);
    rb_define_method(cWindow, "addch", window_addch, 1);
    rb_define_method(cWindow, "insch", window_insch, 1);
    rb_define_method(cWindow, "addstr", window_addstr, 1);
    rb_define_method(cWindow, "<<", window_addstr2, 1);
    rb_define_method(cWindow, "getch", window_getch, 0);
    rb_define_method(cWindow, "getstr", window_getstr, 0);
    rb_define_method(cWindow, "delch", window_delch, 0);
    rb_define_method(cWindow, "deleteln", window_deleteln, 0);
}
