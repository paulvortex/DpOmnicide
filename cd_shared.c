/*
Copyright (C) 1996-1997 Id Software, Inc.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

*/
// Quake is a trademark of Id Software, Inc., (c) 1996 Id Software, Inc. All
// rights reserved.

#include "quakedef.h"
#include "cdaudio.h"
#include "sound.h"

// used by menu to ghost CD audio slider
cvar_t cdaudioinitialized = {CVAR_READONLY,"cdaudioinitialized","0","indicates if CD Audio system is active"};
cvar_t cdaudio = {CVAR_SAVE,"cdaudio","1","CD playing mode (0 = never access CD drive, 1 = play CD tracks if no replacement available, 2 = play fake tracks if no CD track available, 3 = play only real CD tracks, 4 = play real CD tracks even instead of named fake tracks)"};
cvar_t cdaudio_stopbetweenmaps = {0, "cdaudio_stopbetweenmaps", "1", "stop CD audio and fake track playing between map changes/disconnects/etc."};

#define MAX_PLAYLISTS 10
int music_playlist_active = -1;
int music_playlist_playing = 0; // 0 = not playing, 1 = playing, -1 = tried and failed

cvar_t music_playlist_index = {0, "music_playlist_index", "-1", "selects which of the music_playlist_ variables is the active one, -1 disables playlists"};
cvar_t music_playlist_list[MAX_PLAYLISTS] =
{
	{0, "music_playlist_list0", "", "list of tracks to play"},
	{0, "music_playlist_list1", "", "list of tracks to play"},
	{0, "music_playlist_list2", "", "list of tracks to play"},
	{0, "music_playlist_list3", "", "list of tracks to play"},
	{0, "music_playlist_list4", "", "list of tracks to play"},
	{0, "music_playlist_list5", "", "list of tracks to play"},
	{0, "music_playlist_list6", "", "list of tracks to play"},
	{0, "music_playlist_list7", "", "list of tracks to play"},
	{0, "music_playlist_list8", "", "list of tracks to play"},
	{0, "music_playlist_list9", "", "list of tracks to play"}
};
cvar_t music_playlist_current[MAX_PLAYLISTS] =
{
	{0, "music_playlist_current0", "0", "current track index to play in list"},
	{0, "music_playlist_current1", "0", "current track index to play in list"},
	{0, "music_playlist_current2", "0", "current track index to play in list"},
	{0, "music_playlist_current3", "0", "current track index to play in list"},
	{0, "music_playlist_current4", "0", "current track index to play in list"},
	{0, "music_playlist_current5", "0", "current track index to play in list"},
	{0, "music_playlist_current6", "0", "current track index to play in list"},
	{0, "music_playlist_current7", "0", "current track index to play in list"},
	{0, "music_playlist_current8", "0", "current track index to play in list"},
	{0, "music_playlist_current9", "0", "current track index to play in list"},
};
cvar_t music_playlist_random[MAX_PLAYLISTS] =
{
	{0, "music_playlist_random0", "0", "enables random play order if 1, 0 is sequential play"},
	{0, "music_playlist_random1", "0", "enables random play order if 1, 0 is sequential play"},
	{0, "music_playlist_random2", "0", "enables random play order if 1, 0 is sequential play"},
	{0, "music_playlist_random3", "0", "enables random play order if 1, 0 is sequential play"},
	{0, "music_playlist_random4", "0", "enables random play order if 1, 0 is sequential play"},
	{0, "music_playlist_random5", "0", "enables random play order if 1, 0 is sequential play"},
	{0, "music_playlist_random6", "0", "enables random play order if 1, 0 is sequential play"},
	{0, "music_playlist_random7", "0", "enables random play order if 1, 0 is sequential play"},
	{0, "music_playlist_random8", "0", "enables random play order if 1, 0 is sequential play"},
	{0, "music_playlist_random9", "0", "enables random play order if 1, 0 is sequential play"},
};
cvar_t music_playlist_sampleposition[MAX_PLAYLISTS] =
{
	{0, "music_playlist_sampleposition0", "-1", "resume position for track, -1 restarts every time"},
	{0, "music_playlist_sampleposition1", "-1", "resume position for track, -1 restarts every time"},
	{0, "music_playlist_sampleposition2", "-1", "resume position for track, -1 restarts every time"},
	{0, "music_playlist_sampleposition3", "-1", "resume position for track, -1 restarts every time"},
	{0, "music_playlist_sampleposition4", "-1", "resume position for track, -1 restarts every time"},
	{0, "music_playlist_sampleposition5", "-1", "resume position for track, -1 restarts every time"},
	{0, "music_playlist_sampleposition6", "-1", "resume position for track, -1 restarts every time"},
	{0, "music_playlist_sampleposition7", "-1", "resume position for track, -1 restarts every time"},
	{0, "music_playlist_sampleposition8", "-1", "resume position for track, -1 restarts every time"},
	{0, "music_playlist_sampleposition9", "-1", "resume position for track, -1 restarts every time"},
};

static qboolean wasPlaying = false;
static qboolean initialized = false;
static qboolean enabled = false;
static float cdvolume;
typedef char filename_t[MAX_QPATH];
#ifdef MAXTRACKS
static filename_t remap[MAXTRACKS];
#endif
static unsigned char maxTrack;

typedef struct faketrack_s
{
	sfx_t       *sfx;
	int          channel;
	float        volume;
	faketrack_s  *next;

	float        opt_startpos;
	qboolean     opt_looping;
	float        opt_fadein;
	float        opt_fadeout;
	qboolean     opt_crossfade;
	float        opt_volumemod;
	unsigned int pl_tracknum;
	filename_t   pl_trackname;

	double       createtime;
	qboolean     paused;
}faketrack_t;

faketrack_t *faketracks = NULL;

static float saved_vol = 1.0f;

// exported variables
qboolean cdValid = false;
qboolean cdPlaying = false;
qboolean cdPlayLooping = false;
unsigned char cdPlayTrack;

cl_cdstate_t cd;

// get fake track structure for sfx channel
faketrack_t *CDAudio_FakeTrackForChannel(int channel)
{
	faketrack_t *track;

	for (track = faketracks; track; track = track->next)
		if (channel == track->channel)
			return track;
	return NULL;
}

// check if specified channel belongs to CDAudio fake track
qboolean CDAudio_IsFakeTrack(int channel)
{
	return CDAudio_FakeTrackForChannel(channel) ? true : false;
}

// stop fake track
void CDAudio_FakeTrack_Stop(faketrack_t *track)
{
	if (track->channel == -1)
		return;
	S_StopChannel(track->channel, true, false);
	track->channel = -1;
}

// free fake track
void S_FreeSfx (sfx_t *sfx, qboolean force);
void CDAudio_FakeTrack_Free(faketrack_t *track)
{
	faketrack_t *prev;

	if (!track)
		return;

	// stop sfx
	CDAudio_FakeTrack_Stop(track);
	// free sfx
	for (prev = faketracks; prev; prev = prev->next)
		if (prev->sfx == track->sfx)
			if (prev != track) 
				break;
	if (!prev)
		S_FreeSfx(track->sfx, true);
	// remove from chain
	if (faketracks == track)
		faketracks = track->next;
	else
	{
		for (prev = faketracks; prev; prev = prev->next)
			if (prev->next == track)
				prev->next = track->next;
	}
	// free
	Z_Free(track);
}

// play actual fake track
void CDAudio_FakeTrack_Start(faketrack_t *track)
{
	CDAudio_FakeTrack_Stop(track);
	track->channel = S_StartSound_StartPosition_Flags(-1, 0, track->sfx, vec3_origin, track->volume * cdvolume, 0, track->opt_startpos, (track->opt_looping ? CHANNELFLAG_FORCELOOP : 0) | CHANNELFLAG_FULLVOLUME | CHANNELFLAG_LOCALSOUND, 1.0f);

	// play message
	if (track->pl_tracknum >= 1)
	{
		if (cdaudio.integer != 0) // we don't need these messages if only fake tracks can be played anyway
			Con_DPrintf ("Fake CD track %u playing...\n", track->pl_tracknum);
	}
	else
		Con_DPrintf ("BGM track %s playing...\n", track->pl_trackname);
}

// play fake track
void CDAudio_FakeTrack_Play(unsigned int playlist_tracknum, const char *playlist_trackname, char *filename, float volume, float startpos, qboolean looping, float fadein, float fadeout, qboolean crossfade)
{
	faketrack_t *track;
	sfx_t* sfx;

	if (!FS_FileExists(filename) || !(sfx = S_PrecacheSound(filename, false, false)))
		return;

	// if this track already playing - derive position from it
	if (startpos == -1)
	{
		for (track = faketracks; track; track = track->next)
			if (track->sfx == sfx)
				if (track->channel != -1)
					break;
		if (track)
			startpos = S_GetChannelPosition(track->channel);
	}
	if (startpos == -1)
		startpos = 0;

	// allocate fake track
	track = (faketrack_t *)Z_Malloc(sizeof(faketrack_t));
	memset(track, 0, sizeof(faketrack_t));
	track->sfx = sfx;
	track->channel = -1;
	track->opt_fadein = fadein;
	track->opt_fadeout = fadeout;
	track->opt_volumemod = volume;
	track->opt_crossfade = crossfade;
	track->opt_startpos = startpos;
	track->opt_looping = looping;
	track->pl_tracknum = playlist_tracknum;
	strlcpy(track->pl_trackname, playlist_trackname, sizeof(filename_t));
	track->createtime = Sys_DirtyTime();
	track->next = faketracks;
	faketracks = track;
}

static void CDAudio_Eject (void)
{
	if (!enabled)
		return;
	
	if(cdaudio.integer == 0)
		return;

	CDAudio_SysEject();
}


static void CDAudio_CloseDoor (void)
{
	if (!enabled)
		return;

	if(cdaudio.integer == 0)
		return;

	CDAudio_SysCloseDoor();
}

static int CDAudio_GetAudioDiskInfo (void)
{
	int ret;

	cdValid = false;

	if(cdaudio.integer == 0)
		return -1;

	ret = CDAudio_SysGetAudioDiskInfo();
	if (ret < 1)
		return -1;

	cdValid = true;
	maxTrack = ret;

	return 0;
}

static qboolean CDAudio_Play_real (int track, qboolean looping, qboolean complain)
{
	if(track < 1)
	{
		if(complain)
			Con_Print("Could not load BGM track.\n");
		return false;
	}

	if (!cdValid)
	{
		CDAudio_GetAudioDiskInfo();
		if (!cdValid)
		{
			if(complain)
				Con_DPrint ("No CD in player.\n");
			return false;
		}
	}

	if (track > maxTrack)
	{
		if(complain)
			Con_DPrintf("CDAudio: Bad track number %u.\n", track);
		return false;
	}

	if (CDAudio_SysPlay(track) == -1)
		return false;

	if(cdaudio.integer != 3)
		Con_DPrintf ("CD track %u playing...\n", track);

	return true;
}

void CDAudio_Play_byName (const char *trackname, qboolean looping, qboolean tryreal, float startposition, float fadein, float fadeout, qboolean crossfade, float volume)
{
	unsigned int track;
	char filename[MAX_QPATH];

	Host_StartVideo();

	if (!enabled)
		return;

	if(tryreal && strspn(trackname, "0123456789") == strlen(trackname))
	{
		track = (unsigned char) atoi(trackname);
#ifdef MAXTRACKS
		if(track > 0 && track < MAXTRACKS)
			if(*remap[track])
			{
				if(strspn(remap[track], "0123456789") == strlen(remap[track]))
				{
					trackname = remap[track];
				}
				else
				{
					// ignore remappings to fake tracks if we're going to play a real track
					switch(cdaudio.integer)
					{
						case 0: // we never access CD
						case 1: // we have a replacement
							trackname = remap[track];
							break;
						case 2: // we only use fake track replacement if CD track is invalid
							CDAudio_GetAudioDiskInfo();
							if(!cdValid || track > maxTrack)
								trackname = remap[track];
							break;
						case 3: // we always play from CD - ignore this remapping then
						case 4: // we randomize anyway
							break;
					}
				}
			}
#endif
	}

	if(tryreal && strspn(trackname, "0123456789") == strlen(trackname))
	{
		track = (unsigned char) atoi(trackname);
		if (track < 1)
		{
			Con_DPrintf("CDAudio: Bad track number %u.\n", track);
			return;
		}
	}
	else
		track = 0;

	// div0: I assume this code was intentionally there. Maybe turn it into a cvar?
	if (cdPlaying && cdPlayTrack == track && !faketracks)
		return;

	if (!faketracks || (!fadein && !fadeout))
		CDAudio_Stop ();

	if(track >= 1)
	{
		if(cdaudio.integer == 3) // only play real CD tracks at all
		{
			if(CDAudio_Play_real(track, looping, true))
				goto success;
			return;
		}

		if(cdaudio.integer == 2) // prefer real CD track over fake
		{
			if(CDAudio_Play_real(track, looping, false))
				goto success;
		}
	}

	if(cdaudio.integer == 4) // only play real CD tracks, EVEN instead of fake tracks!
	{
		if(CDAudio_Play_real(track, looping, false))
			goto success;
		
		if(cdValid && maxTrack > 0)
		{
			track = 1 + (rand() % maxTrack);
			if(CDAudio_Play_real(track, looping, true))
				goto success;
		}
		else
		{
			Con_DPrint ("No CD in player.\n");
		}
		return;
	}

	// Try playing a fake track (sound file) first
	if(track >= 1)
	{
		                              dpsnprintf(filename, sizeof(filename), "sound/cdtracks/track%03u.wav", track);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "sound/cdtracks/track%03u.ogg", track);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "music/track%03u.ogg", track);// added by motorsep
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "music/cdtracks/track%03u.ogg", track);// added by motorsep
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "sound/cdtracks/track%02u.wav", track);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "sound/cdtracks/track%02u.ogg", track);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "music/track%02u.ogg", track);// added by motorsep
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "music/cdtracks/track%02u.ogg", track);// added by motorsep
	}
	else
	{
		                              dpsnprintf(filename, sizeof(filename), "%s", trackname);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "%s.wav", trackname);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "%s.ogg", trackname);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "sound/%s", trackname);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "sound/%s.wav", trackname);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "sound/%s.ogg", trackname);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "sound/cdtracks/%s", trackname);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "sound/cdtracks/%s.wav", trackname);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "sound/cdtracks/%s.ogg", trackname);
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "music/%s.ogg", trackname); // added by motorsep
		if (!FS_FileExists(filename)) dpsnprintf(filename, sizeof(filename), "music/cdtracks/%s.ogg", trackname); // added by motorsep
	}
	CDAudio_FakeTrack_Play(track, trackname, filename, volume, startposition, looping, fadein, fadeout, crossfade);

	// If we can't play a fake CD track, try the real one
	if (!faketracks)
	{
		if(cdaudio.integer == 0 || track < 1)
		{
			Con_Print("Could not load BGM track.\n");
			return;
		}
		else
		{
			if(!CDAudio_Play_real(track, looping, true))
				return;
		}
	}

success:
	cdPlayLooping = looping;
	cdPlayTrack = track;
	cdPlaying = true;

	if (cdvolume == 0.0 || bgmvolume.value == 0)
		CDAudio_Pause ();
}

void CDAudio_Play (int track, qboolean looping)
{
	char buf[20];
	if (music_playlist_index.integer >= 0)
		return;
	dpsnprintf(buf, sizeof(buf), "%d", (int) track);
	CDAudio_Play_byName(buf, looping, true, -1, 0, 0, false, 1.0);
}

float CDAudio_GetPosition (void)
{
	faketrack_t *track;

	if (faketracks)
	{
		// get position of most recent played faketrack
		for (track = faketracks; track; track = track->next)
			if (track->channel != -1)
				return S_GetChannelPosition(track->channel);
		return -1;
	}
	return -1;
}

static void CDAudio_StopPlaylistTrack(void);

void CDAudio_Stop (void)
{
	if (!enabled)
		return;

	// save the playlist position
	CDAudio_StopPlaylistTrack();

	if (faketracks)
	{
		// stop all fake tracks
		while(faketracks)
			CDAudio_FakeTrack_Free(faketracks);
	}
	else if (cdPlaying && (CDAudio_SysStop() == -1))
		return;
	else if(wasPlaying)
	{
		CDAudio_Resume(); // needed by SDL - can't stop while paused there (causing pause/stop to fail after play, pause, stop, play otherwise)
		if (cdPlaying && (CDAudio_SysStop() == -1))
			return;
	}

	wasPlaying = false;
	cdPlaying = false;
}

void CDAudio_Pause (void)
{
	faketrack_t *track;

	if (!enabled || !cdPlaying)
		return;

	if (faketracks)
	{
		// pause all fake tracks
		for (track = faketracks; track; track = track->next)
		{
			if (track->channel != -1)
			{
				S_SetChannelFlag(track->channel, CHANNELFLAG_PAUSED, true);
				track->paused = true;
			}
		}
	}
	else if (CDAudio_SysPause() == -1)
		return;

	wasPlaying = cdPlaying;
	cdPlaying = false;
}


void CDAudio_Resume (void)
{
	faketrack_t *track;

	if (!enabled || cdPlaying || !wasPlaying)
		return;

	if (faketracks)
	{
		// resume all fake tracks
		for (track = faketracks; track; track = track->next)
		{
			if (track->channel != -1)
			{
				S_SetChannelFlag(track->channel, CHANNELFLAG_PAUSED, false);
				track->paused = false;
			}
		}
	}
	else if (CDAudio_SysResume() == -1)
		return;
	cdPlaying = true;
}

static void CD_f (void)
{
	const char *command;
	faketrack_t *track;

#ifdef MAXTRACKS
	int ret;
	int n;
#endif

	command = Cmd_Argv (1);

	if (strcasecmp(command, "remap") != 0)
		Host_StartVideo();

	if (strcasecmp(command, "on") == 0)
	{
		enabled = true;
		return;
	}

	if (strcasecmp(command, "off") == 0)
	{
		CDAudio_Stop();
		enabled = false;
		return;
	}

	if (strcasecmp(command, "reset") == 0)
	{
		enabled = true;
		CDAudio_Stop();
#ifdef MAXTRACKS
		for (n = 0; n < MAXTRACKS; n++)
			*remap[n] = 0; // empty string, that is, unremapped
#endif
		CDAudio_GetAudioDiskInfo();
		return;
	}

	if (strcasecmp(command, "rescan") == 0)
	{
		CDAudio_Shutdown();
		CDAudio_Startup();
		return;
	}

	if (strcasecmp(command, "remap") == 0)
	{
#ifdef MAXTRACKS
		ret = Cmd_Argc() - 2;
		if (ret <= 0)
		{
			for (n = 1; n < MAXTRACKS; n++)
				if (*remap[n])
					Con_Printf("  %u -> %s\n", n, remap[n]);
			return;
		}
		for (n = 1; n <= ret; n++)
			strlcpy(remap[n], Cmd_Argv (n+1), sizeof(*remap));
#endif
		return;
	}

	if (strcasecmp(command, "close") == 0)
	{
		CDAudio_CloseDoor();
		return;
	}

	if (strcasecmp(command, "play") == 0)
	{
		if (music_playlist_index.integer >= 0)
			return;
		CDAudio_Play_byName(Cmd_Argv (2), false, true, (Cmd_Argc() > 3) ? atof(Cmd_Argv(3)) : -1, 0, 0, false, 1.0f);
		return;
	}

	if (strcasecmp(command, "loop") == 0)
	{
		if (music_playlist_index.integer >= 0)
			return;
		CDAudio_Play_byName(Cmd_Argv (2), true, true, (Cmd_Argc() > 3) ? atof(Cmd_Argv(3)) : -1, 0, 0, false, 1.0f);
		return;
	}

	if (strcasecmp(command, "playfake") == 0)
	{
		if (music_playlist_index.integer >= 0)
			return;
		qboolean loop = false;
		qboolean crossfade = false;
		float    fadein = 0.0f;
		float    fadeout = 0.0f;
		float    volume = 1.0f;
		float    startpos = -1.0f;
		for (int i = 3; i < Cmd_Argc(); i++)
		{
			if (strcasecmp(Cmd_Argv(i), "startpos") == 0)
			{
				i++;
				if (i < Cmd_Argc())
					startpos = atof(Cmd_Argv(i));
				continue;
			}
			if (strcasecmp(Cmd_Argv(i), "volume") == 0)
			{
				i++;
				if (i < Cmd_Argc())
					volume = atof(Cmd_Argv(i));
				continue;
			}
			if (strcasecmp(Cmd_Argv(i), "fadein") == 0)
			{
				i++;
				if (i < Cmd_Argc())
					fadein = atof(Cmd_Argv(i));
				continue;
			}
			if (strcasecmp(Cmd_Argv(i), "fadeout") == 0)
			{
				i++;
				if (i < Cmd_Argc())
					fadeout = atof(Cmd_Argv(i));
				continue;
			}
			if (strcasecmp(Cmd_Argv(i), "loop") == 0)
			{
				loop = true;
				continue;
			}
			if (strcasecmp(Cmd_Argv(i), "crossfade") == 0)
			{
				crossfade = true;
				continue;
			}
		}
		CDAudio_Play_byName(Cmd_Argv (2), loop, false, startpos, fadein, fadeout, crossfade, volume);
		return;
	}

	if (strcasecmp(command, "stop") == 0)
	{
		if (music_playlist_index.integer >= 0)
			return;
		CDAudio_Stop();
		return;
	}

	if (strcasecmp(command, "pause") == 0)
	{
		if (music_playlist_index.integer >= 0)
			return;
		CDAudio_Pause();
		return;
	}

	if (strcasecmp(command, "resume") == 0)
	{
		if (music_playlist_index.integer >= 0)
			return;
		CDAudio_Resume();
		return;
	}

	if (strcasecmp(command, "eject") == 0)
	{
		if (!faketracks)
			CDAudio_Stop();
		CDAudio_Eject();
		cdValid = false;
		return;
	}

	if (strcasecmp(command, "info") == 0)
	{
		CDAudio_GetAudioDiskInfo ();
		if (cdValid)
			Con_Printf("%u tracks on CD.\n", maxTrack);
		else
			Con_Print ("No CD in player.\n");
		if (cdPlaying)
			Con_Printf("Currently %s track %u\n", cdPlayLooping ? "looping" : "playing", cdPlayTrack);
		else if (wasPlaying)
			Con_Printf("Paused %s track %u\n", cdPlayLooping ? "looping" : "playing", cdPlayTrack);
		if (cdvolume >= 0)
			Con_Printf("Volume is %f\n", cdvolume);
		else
			Con_Printf("Can't get CD volume\n");
		if (faketracks)
		{
			Con_Printf("Faketracks playing:\n");
			for (track = faketracks; track; track = track->next)
				Con_Printf(" volume %f file %s\n", track->volume, track->sfx->name);
		}
		return;
	}

	Con_Printf("CD commands:\n");
	Con_Printf("cd on - enables CD audio system\n");
	Con_Printf("cd off - stops and disables CD audio system\n");
	Con_Printf("cd reset - resets CD audio system (clears track remapping and re-reads disc information)\n");
	Con_Printf("cd rescan - rescans disks in drives (to use another disc)\n");
	Con_Printf("cd remap <remap1> [remap2] [remap3] [...] - chooses (possibly emulated) CD tracks to play when a map asks for a particular track, this has many uses\n");
	Con_Printf("cd close - closes CD tray\n");
	Con_Printf("cd eject - stops playing music and opens CD tray to allow you to change disc\n");
	Con_Printf("cd play <tracknumber> [startposition] - plays selected track in remapping table\n");
	Con_Printf("cd loop <tracknumber> [startposition] - plays and repeats selected track in remapping table\n");
	Con_Printf("cd playfake <tracknumber> [startpos x] [fadein x] [fadeout x] [volume x] [crossfade] [loop] - play emulated track with options\n");
	Con_Printf("cd stop - stops playing current CD track\n");
	Con_Printf("cd pause - pauses CD playback\n");
	Con_Printf("cd resume - unpauses CD playback\n");
	Con_Printf("cd info - prints basic disc information (number of tracks, currently playing track, volume level)\n");
}

static void CDAudio_SetVolume (float newvol)
{
	faketrack_t *track;

	// If the volume hasn't changed
	if (newvol == cdvolume)
		return;

	// If the CD has been muted
	if (newvol == 0.0f)
		CDAudio_Pause ();
	else
	{
		// If the CD has been unmuted
		if (cdvolume == 0.0f)
			CDAudio_Resume ();

		if (faketracks)
		{
			// update volume of all playing fake tracks
			for (track = faketracks; track; track = track->next)
				if (track->channel)
					S_SetChannelVolume(track->channel, track->volume * track->opt_volumemod * newvol);
		}
		else
			CDAudio_SysSetVolume (newvol * mastervolume.value);
	}

	cdvolume = newvol;
}

static void CDAudio_StopPlaylistTrack(void)
{
	if (music_playlist_active >= 0 && music_playlist_active < MAX_PLAYLISTS && music_playlist_sampleposition[music_playlist_active].value >= 0)
	{
		// save position for resume
		float position = CDAudio_GetPosition();
		Cvar_SetValueQuick(&music_playlist_sampleposition[music_playlist_active], position >= 0 ? position : 0);
	}
	music_playlist_active = -1;
	music_playlist_playing = 0; // not playing
}

void CDAudio_StartPlaylist(qboolean resume)
{
	const char *list;
	const char *t;
	int index;
	int current;
	int randomplay;
	int count;
	int listindex;
	float position;
	char trackname[MAX_QPATH];
	CDAudio_Stop();
	index = music_playlist_index.integer;
	if (index >= 0 && index < MAX_PLAYLISTS && bgmvolume.value > 0)
	{
		list = music_playlist_list[index].string;
		current = music_playlist_current[index].integer;
		randomplay = music_playlist_random[index].integer;
		position = music_playlist_sampleposition[index].value;
		count = 0;
		trackname[0] = 0;
		if (list && list[0])
		{
			for (t = list;;count++)
			{
				if (!COM_ParseToken_Console(&t))
					break;
				// if we don't find the desired track, use the first one
				if (count == 0)
					strlcpy(trackname, com_token, sizeof(trackname));
			}
		}
		if (count > 0)
		{
			// position < 0 means never resume track
			if (position < 0)
				position = 0;
			// advance to next track in playlist if the last one ended
			if (!resume)
			{
				position = 0;
				current++;
				if (randomplay)
					current = (int)lhrandom(0, count);
			}
			// wrap playlist position if needed
			if (current >= count)
				current = 0;
			// set current
			Cvar_SetValueQuick(&music_playlist_current[index], current);
			// get the Nth trackname
			if (current >= 0 && current < count)
			{
				for (listindex = 0, t = list;;listindex++)
				{
					if (!COM_ParseToken_Console(&t))
						break;
					if (listindex == current)
					{
						strlcpy(trackname, com_token, sizeof(trackname));
						break;
					}
				}
			}
			if (trackname[0])
			{
				CDAudio_Play_byName(trackname, false, false, position, 0, 0, false, 1.0f);
				if (faketracks)
					music_playlist_active = index;
			}
		}
	}
	music_playlist_playing = music_playlist_active >= 0 ? 1 : -1;
}

double cdupdatetime;

void CDAudio_Update (void)
{
	static int lastplaylist = -1;
	double frametime, newtime;
	float maxvol, fadein, fadeout;
	faketrack_t *track, *next;

	if (!enabled)
		return;

	// update fake tracks
	newtime = Sys_DirtyTime();
	frametime = newtime - cdupdatetime;
	cdupdatetime = newtime;
	if (faketracks)
	{
		// since using non-linear fade, timers (which fadein and fadeout are) is not very accurate
		fadein = faketracks->opt_fadein ? (1.0 / faketracks->opt_fadein) * frametime : 1.0f;
		if (fadein > 1.0)
			fadein = 1.0;
		fadeout = faketracks->opt_fadeout ? (1.0 / faketracks->opt_fadeout) * frametime * 4.0 : 1.0f;
		if (fadeout > 1.0)
			fadeout = 1.0;

		// maximal volume of background tracks
		maxvol = 0.0f;
		for (track = faketracks->next; track; track = track->next)
			if (track->channel != -1)
				maxvol = max(maxvol, track->volume);

		// fade in foreground
		if (faketracks->volume < 1.0f && (faketracks->opt_crossfade || maxvol <= 0.01f))
			faketracks->volume = faketracks->volume * (1.0 - fadein) + fadein;
		if (faketracks->volume)
		{
			 if (faketracks->channel == -1)
				 CDAudio_FakeTrack_Start(faketracks);
			 else
				S_SetChannelVolume(faketracks->channel, faketracks->volume * faketracks->opt_volumemod * cdvolume);
		}

		// fade out background
		for (track = faketracks->next; track; track = next)
		{
			next = track->next;
			track->volume = track->volume * (1.0 - fadeout);
			if (track->volume <= 0.01f || track->channel == -1)
				CDAudio_FakeTrack_Free(track);
			else
				S_SetChannelVolume(track->channel, track->volume * track->opt_volumemod * cdvolume);
			fadeout = min(1.0f, fadeout * 4.0); // increase fading speed when moving chain
		}
	}

	CDAudio_SetVolume (bgmvolume.value);
	if (music_playlist_playing > 0 && CDAudio_GetPosition() < 0)
	{
		// this track ended, start a new track from the beginning
		CDAudio_StartPlaylist(false);
		lastplaylist = music_playlist_index.integer;
	}
	else if (lastplaylist != music_playlist_index.integer || (bgmvolume.value > 0 && !music_playlist_playing && music_playlist_index.integer >= 0))
	{
		// active playlist changed, save position and switch track
		CDAudio_StartPlaylist(true);
		lastplaylist = music_playlist_index.integer;
	}

	if (!faketracks && cdaudio.integer != 0 && bgmvolume.value != 0)
		CDAudio_SysUpdate();
}

int CDAudio_Init (void)
{
	int i;

	if (cls.state == ca_dedicated)
		return -1;

// COMMANDLINEOPTION: Sound: -nocdaudio disables CD audio support
	if (COM_CheckParm("-nocdaudio"))
		return -1;

	CDAudio_SysInit();

	cdupdatetime = Sys_DirtyTime();

#ifdef MAXTRACKS
	for (i = 0; i < MAXTRACKS; i++)
		*remap[i] = 0;
#endif

	Cvar_RegisterVariable(&cdaudio);
	Cvar_RegisterVariable(&cdaudioinitialized);
	Cvar_RegisterVariable(&cdaudio_stopbetweenmaps);
	Cvar_SetValueQuick(&cdaudioinitialized, true);
	enabled = true;

	Cvar_RegisterVariable(&music_playlist_index);
	for (i = 0;i < MAX_PLAYLISTS;i++)
	{
		Cvar_RegisterVariable(&music_playlist_list[i]);
		Cvar_RegisterVariable(&music_playlist_current[i]);
		Cvar_RegisterVariable(&music_playlist_random[i]);
		Cvar_RegisterVariable(&music_playlist_sampleposition[i]);
	}

	Cmd_AddCommand("cd", CD_f, "execute a CD drive command (cd on/off/reset/remap/close/play/loop/stop/pause/resume/eject/info) - use cd by itself for usage");

	return 0;
}

int CDAudio_Startup (void)
{
	if (COM_CheckParm("-nocdaudio"))
		return -1;

	CDAudio_SysStartup ();

	if (CDAudio_GetAudioDiskInfo())
	{
		Con_Print("CDAudio_Init: No CD in player.\n");
		cdValid = false;
	}

	saved_vol = CDAudio_SysGetVolume ();
	if (saved_vol < 0.0f)
	{
		Con_Print ("Can't get initial CD volume\n");
		saved_vol = 1.0f;
	}
	else
		Con_Printf ("Initial CD volume: %g\n", saved_vol);

	initialized = true;

	Con_Print("CD Audio Initialized\n");

	return 0;
}

void CDAudio_Shutdown (void)
{
	if (!initialized)
		return;

	CDAudio_SysSetVolume (saved_vol);

	CDAudio_Stop();
	CDAudio_SysShutdown();
	initialized = false;
}
