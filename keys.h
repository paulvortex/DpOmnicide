/*
	$RCSfile$

	Copyright (C) 1996-1997  Id Software, Inc.

	This program is free software; you can redistribute it and/or
	modify it under the terms of the GNU General Public License
	as published by the Free Software Foundation; either version 2
	of the License, or (at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

	See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program; if not, write to:

		Free Software Foundation, Inc.
		59 Temple Place - Suite 330
		Boston, MA  02111-1307, USA

	$Id: keys.h 11463 2011-10-22 23:52:58Z havoc $
*/

#ifndef __KEYS_H
#define __KEYS_H

#include "qtypes.h"

//
// these are the key numbers that should be passed to Key_Event
//
typedef enum keynum_e
{
	K_TEXT			= 1, // used only for unicode character input
	K_TAB			= 9,
	K_ENTER			= 13,
	K_ESCAPE		= 27,
	K_SPACE			= 32,

	// normal keys should be passed as lowercased ascii

	K_BACKSPACE		= 127,
	K_UPARROW,
	K_DOWNARROW,
	K_LEFTARROW,
	K_RIGHTARROW,

	K_ALT,
	K_CTRL,
	K_SHIFT,

	K_F1,
	K_F2,
	K_F3,
	K_F4,
	K_F5,
	K_F6,
	K_F7,
	K_F8,
	K_F9,
	K_F10,
	K_F11,
	K_F12,

	K_INS,
	K_DEL,
	K_PGDN,
	K_PGUP,
	K_HOME,
	K_END,

	K_PAUSE,

	K_NUMLOCK,
	K_CAPSLOCK,
	K_SCROLLOCK,

	K_KP_0,
	K_KP_INS = K_KP_0,
	K_KP_1,
	K_KP_END = K_KP_1,
	K_KP_2,
	K_KP_DOWNARROW = K_KP_2,
	K_KP_3,
	K_KP_PGDN = K_KP_3,
	K_KP_4,
	K_KP_LEFTARROW = K_KP_4,
	K_KP_5,
	K_KP_6,
	K_KP_RIGHTARROW = K_KP_6,
	K_KP_7,
	K_KP_HOME = K_KP_7,
	K_KP_8,
	K_KP_UPARROW = K_KP_8,
	K_KP_9,
	K_KP_PGUP = K_KP_9,
	K_KP_PERIOD,
	K_KP_DEL = K_KP_PERIOD,
	K_KP_DIVIDE,
	K_KP_SLASH = K_KP_DIVIDE,
	K_KP_MULTIPLY,
	K_KP_MINUS,
	K_KP_PLUS,
	K_KP_ENTER,
	K_KP_EQUALS,

	K_PRINTSCREEN,

	// mouse buttons generate virtual keys

	K_MOUSE1 = 512,
	K_OTHERDEVICESBEGIN = K_MOUSE1,
	K_MOUSE2,
	K_MOUSE3,
	K_MWHEELUP,
	K_MWHEELDOWN,
	K_MOUSE4,
	K_MOUSE5,
	K_MOUSE6,
	K_MOUSE7,
	K_MOUSE8,
	K_MOUSE9,
	K_MOUSE10,
	K_MOUSE11,
	K_MOUSE12,
	K_MOUSE13,
	K_MOUSE14,
	K_MOUSE15,
	K_MOUSE16,

//
// joystick buttons
//
	K_JOY1 = 768,
	K_JOY2, // 769
	K_JOY3, // 770
	K_JOY4, // 771
	K_JOY5, // 772
	K_JOY6, // 773
	K_JOY7, // 774
	K_JOY8, // 775
	K_JOY9, // 776
	K_JOY10, // 777
	K_JOY11, // 778
	K_JOY12, // 779
	K_JOY13, // 780
	K_JOY14, // 781
	K_JOY15, // 782
	K_JOY16, // 783

//
// aux keys are for multi-buttoned joysticks to generate so they can use
// the normal binding process
//
	K_AUX1, // 784
	K_AUX2, // 785
	K_AUX3, // 786
	K_AUX4, // 787
	K_AUX5, // 788
	K_AUX6, // 789
	K_AUX7, // 790
	K_AUX8, // 791
	K_AUX9, // 792
	K_AUX10, // 793
	K_AUX11, // 794
	K_AUX12, // 795
	K_AUX13, // 796
	K_AUX14, // 797
	K_AUX15, // 798
	K_AUX16, // 799
	K_AUX17, // 800
	K_AUX18, // 801
	K_AUX19, // 802
	K_AUX20, // 803
	K_AUX21, // 804
	K_AUX22, // 805
	K_AUX23, // 806
	K_AUX24, // 807
	K_AUX25, // 808
	K_AUX26, // 809
	K_AUX27, // 810
	K_AUX28, // 811
	K_AUX29, // 812
	K_AUX30, // 813
	K_AUX31, // 814
	K_AUX32, // 815

	// Microsoft Xbox 360 Controller For Windows
	K_X360_DPAD_UP, // 816
	K_X360_DPAD_DOWN, // 817
	K_X360_DPAD_LEFT, // 818
	K_X360_DPAD_RIGHT, // 819
	K_X360_START, // 820
	K_X360_BACK, // 821
	K_X360_LEFT_THUMB, // 822
	K_X360_RIGHT_THUMB, // 823
	K_X360_LEFT_SHOULDER, // 824
	K_X360_RIGHT_SHOULDER, // 825
	K_X360_A, // 826
	K_X360_B, // 827
	K_X360_X, // 828
	K_X360_Y, // 829
	K_X360_LEFT_TRIGGER, // 830
	K_X360_RIGHT_TRIGGER, // 831
	K_X360_LEFT_THUMB_UP, // 832
	K_X360_LEFT_THUMB_DOWN, // 833
	K_X360_LEFT_THUMB_LEFT, // 834
	K_X360_LEFT_THUMB_RIGHT, // 335
	K_X360_RIGHT_THUMB_UP, // 836
	K_X360_RIGHT_THUMB_DOWN, // 837
	K_X360_RIGHT_THUMB_LEFT, // 838
	K_X360_RIGHT_THUMB_RIGHT, // 839

	// generic joystick emulation for menu
	K_JOY_UP, // 840
	K_JOY_DOWN, // 841
	K_JOY_LEFT, // 842
	K_JOY_RIGHT, // 843

	// x360 'guide' button
	K_X360_GUIDE, // 844

	// Sony DualShock Controller
	K_DS_DPAD_UP, // 845
	K_DS_DPAD_DOWN, // 846
	K_DS_DPAD_LEFT, // 847
	K_DS_DPAD_RIGHT, // 848
	K_DS_SQUARE, // 849
	K_DS_CROSS, // 850
	K_DS_CIRCLE, // 851
	K_DS_TRIANGLE, // 852
	K_DS_L1, // 853
	K_DS_R1, // 854
	K_DS_L2, // 855
	K_DS_R2, // 856
	K_DS_SHARE, // 857
	K_DS_OPTIONS, // 858
	K_DS_LEFT_STICK, // 859
	K_DS_RIGHT_STICK, // 860
	K_DS_PS, // 861
	K_DS_TOUCHPAD, // 862
	K_DS_LEFT_STICK_UP, // 863
	K_DS_LEFT_STICK_DOWN, // 864
	K_DS_LEFT_STICK_LEFT, // 865
	K_DS_LEFT_STICK_RIGHT, // 866
	K_DS_RIGHT_STICK_UP, // 867
	K_DS_RIGHT_STICK_DOWN, // 868
	K_DS_RIGHT_STICK_LEFT, // 869
	K_DS_RIGHT_STICK_RIGHT, // 870

	// Midi keyboard
	K_MIDINOTE0 = 896, // to this, the note number is added
	K_MIDINOTE1,
	K_MIDINOTE2,
	K_MIDINOTE3,
	K_MIDINOTE4,
	K_MIDINOTE5,
	K_MIDINOTE6,
	K_MIDINOTE7,
	K_MIDINOTE8,
	K_MIDINOTE9,
	K_MIDINOTE10,
	K_MIDINOTE11,
	K_MIDINOTE12,
	K_MIDINOTE13,
	K_MIDINOTE14,
	K_MIDINOTE15,
	K_MIDINOTE16,
	K_MIDINOTE17,
	K_MIDINOTE18,
	K_MIDINOTE19,
	K_MIDINOTE20,
	K_MIDINOTE21,
	K_MIDINOTE22,
	K_MIDINOTE23,
	K_MIDINOTE24,
	K_MIDINOTE25,
	K_MIDINOTE26,
	K_MIDINOTE27,
	K_MIDINOTE28,
	K_MIDINOTE29,
	K_MIDINOTE30,
	K_MIDINOTE31,
	K_MIDINOTE32,
	K_MIDINOTE33,
	K_MIDINOTE34,
	K_MIDINOTE35,
	K_MIDINOTE36,
	K_MIDINOTE37,
	K_MIDINOTE38,
	K_MIDINOTE39,
	K_MIDINOTE40,
	K_MIDINOTE41,
	K_MIDINOTE42,
	K_MIDINOTE43,
	K_MIDINOTE44,
	K_MIDINOTE45,
	K_MIDINOTE46,
	K_MIDINOTE47,
	K_MIDINOTE48,
	K_MIDINOTE49,
	K_MIDINOTE50,
	K_MIDINOTE51,
	K_MIDINOTE52,
	K_MIDINOTE53,
	K_MIDINOTE54,
	K_MIDINOTE55,
	K_MIDINOTE56,
	K_MIDINOTE57,
	K_MIDINOTE58,
	K_MIDINOTE59,
	K_MIDINOTE60,
	K_MIDINOTE61,
	K_MIDINOTE62,
	K_MIDINOTE63,
	K_MIDINOTE64,
	K_MIDINOTE65,
	K_MIDINOTE66,
	K_MIDINOTE67,
	K_MIDINOTE68,
	K_MIDINOTE69,
	K_MIDINOTE70,
	K_MIDINOTE71,
	K_MIDINOTE72,
	K_MIDINOTE73,
	K_MIDINOTE74,
	K_MIDINOTE75,
	K_MIDINOTE76,
	K_MIDINOTE77,
	K_MIDINOTE78,
	K_MIDINOTE79,
	K_MIDINOTE80,
	K_MIDINOTE81,
	K_MIDINOTE82,
	K_MIDINOTE83,
	K_MIDINOTE84,
	K_MIDINOTE85,
	K_MIDINOTE86,
	K_MIDINOTE87,
	K_MIDINOTE88,
	K_MIDINOTE89,
	K_MIDINOTE90,
	K_MIDINOTE91,
	K_MIDINOTE92,
	K_MIDINOTE93,
	K_MIDINOTE94,
	K_MIDINOTE95,
	K_MIDINOTE96,
	K_MIDINOTE97,
	K_MIDINOTE98,
	K_MIDINOTE99,
	K_MIDINOTE100,
	K_MIDINOTE101,
	K_MIDINOTE102,
	K_MIDINOTE103,
	K_MIDINOTE104,
	K_MIDINOTE105,
	K_MIDINOTE106,
	K_MIDINOTE107,
	K_MIDINOTE108,
	K_MIDINOTE109,
	K_MIDINOTE110,
	K_MIDINOTE111,
	K_MIDINOTE112,
	K_MIDINOTE113,
	K_MIDINOTE114,
	K_MIDINOTE115,
	K_MIDINOTE116,
	K_MIDINOTE117,
	K_MIDINOTE118,
	K_MIDINOTE119,
	K_MIDINOTE120,
	K_MIDINOTE121,
	K_MIDINOTE122,
	K_MIDINOTE123,
	K_MIDINOTE124,
	K_MIDINOTE125,
	K_MIDINOTE126,
	K_MIDINOTE127,

	MAX_KEYS
}
keynum_t;

typedef enum keydest_e { key_game, key_message, key_menu, key_menu_grabbed, key_console, key_void } keydest_t;

extern	char		key_line[MAX_INPUTLINE];
extern	int			key_linepos;
extern	qboolean	key_insert;	// insert key toggle (for editing)
extern	keydest_t	key_dest;
// key_consoleactive bits
// user wants console (halfscreen)
#define KEY_CONSOLEACTIVE_USER 1
// console forced because there's nothing else active (fullscreen)
#define KEY_CONSOLEACTIVE_FORCED 4
extern	int			key_consoleactive;
extern	char		*keybindings[MAX_BINDMAPS][MAX_KEYS];

extern int chat_mode; // 0 for say, 1 for say_team, -1 for command
extern char chat_buffer[MAX_INPUTLINE];
extern unsigned int chat_bufferlen;

void Key_ClearEditLine(int edit_line);
void Key_WriteBindings(qfile_t *f);
void Key_Init(void);
void Key_Shutdown(void);
void Key_Init_Cvars(void);
void Key_Event(int key, int ascii, qboolean down);
void Key_ReleaseAll (void);
void Key_ClearStates (void); // FIXME: should this function still exist? Or should Key_ReleaseAll be used instead when shutting down a vid driver?
void Key_EventQueue_Block(void);
void Key_EventQueue_Unblock(void);

qboolean Key_SetBinding (int keynum, int bindmap, const char *binding);
const char *Key_GetBind (int key, int bindmap);
void Key_FindKeysForCommand (const char *command, int *keys, int numkeys, int bindmap);
qboolean Key_SetBindMap(int fg, int bg);
void Key_GetBindMap(int *fg, int *bg);

#endif // __KEYS_H

