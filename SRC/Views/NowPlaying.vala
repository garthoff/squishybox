/* Squishybox 
 * Copyright (C) 2010-2011 Qball Cow <qball@sarine.nl>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */
using SDL;
using SDLTTF;
using SDLImage;
using MPD;
using Posix;
using SDLMpc;

/**
 * This is the now playing widget. It shows the song title/artist/album/year
 * It also shows some player control buttons 
 */

class NowPlaying : SDLWidget, SDLWidgetDrawing
{
    private weak Main m;

    private SDLMpc.Label title_label;
    private SDLMpc.Label artist_label;
    private SDLMpc.Label album_label;

    private int current_song_id = -1;

    public override unowned string get_name()
    {
        return "Now playing";
    }

    public NowPlaying(Main main,int16 x, int16 y, uint16 w, uint16 h, int bpp)
    {
        this.m = main;

        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;

        var  sp = new SongProgress      (this.m,
                    (int16)this.x+5,
                    (int16) (this.y+this.h-70),
                    (uint16) (160),
                    (uint16) 22, 
                    bpp);
        this.children.append(sp);

        var pb = new ProgressBar        (this.m, 
                (int16)this.x+150, 
                (int16)(this.y+this.h-65), 
                (uint16)(this.w-180), 
                (uint16)60-43);
        this.children.append(pb);

        this.add_focus_widget(pb);

        var frame   = new PlayerControl     (this.m,
                (int16) this.x,
                (int16) (this.y+this.h-38),
                (uint16) this.w,
                38,
                bpp);
        this.children.append(frame);

        /* Add the children to the focus list of this widget. */
        /* TODO: make this more intergrated. */
        this.add_focus_widget(frame.prev_button);
        this.add_focus_widget(frame.stop_button);
        this.add_focus_widget(frame.pause_button);
        this.add_focus_widget(frame.next_button);
        this.add_focus_widget(frame.volume_bar);

        /* Title label */
        title_label = new SDLMpc.Label	(this.m,FontSize.LARGE,
				(int16) this.x+5,
                (int16) this.y+5,
                (uint16) (this.w-10),
                (uint16) 55);
		this.children.append(title_label);

        /* Artist label */
        artist_label = new SDLMpc.Label	(this.m,FontSize.NORMAL,
				(int16) this.x+5,
                (int16) this.y+65,
                (uint16) (this.w-10),
                (uint16) 40);
		this.children.append(artist_label);
        album_label = new SDLMpc.Label	(this.m,FontSize.SMALL, 	
				(int16) this.x+5,
                (int16) this.y+115,
                (uint16)(this.w-10),
                (uint16) 30);
		this.children.append(album_label);

		title_label.set_text("Disconnected");

        this.m.MI.player_get_current_song(got_current_song);
        this.m.MI.player_connection_changed.connect(connection_changed_callback);
        
        this.m.MI.player_status_changed.connect(status_changed_callback);

    }
    private void status_changed_callback(MPD.Interaction mi, MPD.Status status)
    {
        if((status.state == MPD.Status.State.PLAY || status.state == MPD.Status.State.PAUSE))
        {
            /* Update the text */
            if(status.song_id != current_song_id) {
                this.m.MI.player_get_current_song(got_current_song);
                this.current_song_id = status.song_id;
            }
        }else{
            this.title_label.set_text("Music Player Daemon");
            this.album_label.set_text(null);
            if(status.state == MPD.Status.State.STOP) {
                this.artist_label.set_text("Stopped");
            }
            this.current_song_id = -1;
        }

    }
    private void connection_changed_callback(MPD.Interaction mi, bool connected)
    {
		if(connected) {
			title_label.set_text("");
		}else{
			title_label.set_text("Disconnected");
		}
    }
    public void draw_drawing(Surface screen, SDL.Rect *orect)
    {
    }

    private void got_current_song(MPD.Song? song)
    {
        GLib.debug("Got current song");

        if(song != null)
        {
            string a;
			a = format_song_title(song);
            title_label.set_text(a);

            if((a = song.get_tag(MPD.Tag.Type.ARTIST,0)) == null) {
                a = "";
            }
            artist_label.set_text(a);

            if((a = song.get_tag(MPD.Tag.Type.ALBUM,0)) == null) {
                a = "";
            }
            album_label.set_text(a);
        }else {
            title_label.set_text("Music Player Daemon");

            artist_label.set_text(null);
            album_label.set_text(null);
        }
        this.require_redraw = true;;
    }

    public override void Tick(time_t now)
    {
		if(title_label.scrolling) {
         	title_label.require_redraw = true;
		}
		if(artist_label.scrolling) {
         	artist_label.require_redraw = true;
		}
		if(album_label.scrolling) {
         	album_label.require_redraw = true;
		}
    }
    public override bool Event(SDLMpc.Event ev)
    {
        return false;
    }
}


/**
 * TODO: make this precise (ms - precise)
 */

class SongProgress : SDLWidget, SDLWidgetDrawing
{
    private weak Main m;
    private SDLMpc.Label elapsed_label;
    private SDLMpc.Label total_label;
    private int current_song_id = -1;

    private uint32 elapsed_time = 0;
    private uint32 total_time = 0;
    private bool progressing = false;

	public override unowned string get_name()
	{
		return "SongProgress" ;
	}

    public SongProgress (Main m,int16 x, int16 y, uint16 w, uint16 h, int bpp)
    {
        this.m = m;
        this.x = x; this.y = y; this.h = h; this.w = w;

        elapsed_label = new SDLMpc.Label(this.m,FontSize.SMALL,x,y,w,h);
        this.children.append(elapsed_label);
        this.elapsed_label.set_text("00:00");

        /* initialize */
        m.MI.player_status_changed.connect((source, status) => {
                this.elapsed_time = status.get_elapsed_time(); 
                this.total_time = status.get_total_time(); 

                /* Update total time string */

                if(this.current_song_id != status.song_id)
                {
                    this.current_song_id = status.song_id;
                }
                if(status.state == MPD.Status.State.PLAY) this.progressing = true;
                else this.progressing = false;
                update_time();
                });


    }
    public void draw_drawing(Surface screen, SDL.Rect *orect)
    {
        SDL.Rect rect = {0,0,0,0};

        rect.y = (int16)(screen.h-40-elapsed_label.height());
        rect.x = 5;

//        elapsed_label.render(screen,  5, rect.y);
//        total_label.render(screen, 10+elapsed_label.width(), rect.y);
    }
    private void update_time()
    {
        string a = "%02u:%02u - %02u:%02u".printf(
                elapsed_time/60, elapsed_time%60,
                total_time/60, total_time%60
                );
        elapsed_label.set_text(a);
    }


    private time_t last_time = time_t(); 
    public override void Tick(time_t now)
    {
        if(last_time != now){
            if(progressing) {
                elapsed_time++;
                update_time();
            }

            last_time = now; 
        }
    }
}

class ProgressBar : SDLWidget, SDLWidgetDrawing, SDLWidgetMotion
{
    private Surface button;
    private Surface bar;
    private weak Main m;
    private uint32 elapsed_time = 0;
    private uint32 total_time = 0;
    private uint32 seek_time = 0;
    private bool progressing = false;
    private bool playback = false;

	public override unowned string get_name()
	{
		return "ProgressBar";
	}
    public ProgressBar(Main m, int x, int y, int w, int h)
    {
        this.m = m;
        this.x = x; this.y  = y; this.w = w; this.h = h;

        bar = new Surface.RGB(0, w,8,32,(uint32)0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
        bar = bar.DisplayFormat();

        SDL.Rect rect = {0,0,(uint16)w,(uint16)8};
        bar.fill(rect, bar.format.map_rgb(255,255,255)); 

        rect = {1, 1,(uint16)w-2,(uint16)6};
        bar.fill(rect, bar.format.map_rgb(0,0,0)); 


        button = new Surface.RGB(0, h,h,32,(uint32)0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
        button = button.DisplayFormat();
        rect = {0,0,(uint16)h, (uint16)h};
        button.fill(rect, button.format.map_rgb(255,255,255)); 
        rect = {1,1,(uint16)h-2, (uint16)h-2};
        button.fill(rect, button.format.map_rgb(20,25,255)); 



        /* initialize */
        m.MI.player_status_changed.connect((source, status) => {
                elapsed_time = status.get_elapsed_time(); 
                total_time = status.get_total_time(); 

                if(status.state == MPD.Status.State.STOP) playback = false;
		else playback = true;
                if(status.state == MPD.Status.State.PLAY) progressing = true;
                else progressing = false;
                this.require_redraw = true;
                });

    }

    public void draw_drawing(Surface screen, SDL.Rect *orect)
    {
		if(!playback) return;
		SDL.Rect dest_rect = {0,0,0,0};
		SDL.Rect src_rect = {0,0,0,0};
        float fraction = 0.0f;

        if(total_time > 0) {
            fraction = elapsed_time/(float)total_time;
        }
        if(seeking) {
            fraction = seek_time/(float)total_time;
        }

        dest_rect.x = (int16)this.x;
        dest_rect.y = (int16)(this.y + (this.h-8)/2);
        dest_rect.w = (uint16)this.w;
        dest_rect.h = (uint16)8;

        bar.blit_surface(null, screen, dest_rect);

        dest_rect.y = (int16)this.y;
        dest_rect.h = (uint16)this.h;
        dest_rect.x = (int16)(this.x + (this.w-this.h)*fraction);
		dest_rect.w = (uint16)this.h;
		src_rect.h = src_rect.w = (uint16)this.h;

        button.blit_surface(src_rect, screen, dest_rect);
    }

    private time_t last_time = time_t(); 
    public override void Tick(time_t now)
    {
        if(last_time != now){
            if(progressing) {
                elapsed_time++;
                this.require_redraw = true;
            }
            last_time = now; 
        }
    }
    private bool seeking = false;
    public bool motion(double x, double y, bool pushed, bool released)
    {
        if(this.inside((int)x, (int)y) || seeking)
        {
            if(pushed || seeking)
            {
                if(total_time > 0) {
                    if(!seeking) {
                        if(progressing)
                            this.m.MI.player_toggle_pause();
                        seeking = true;
                    }
                    progressing = false;
                    double fraction = (x-this.x)/this.w;
                    fraction = (fraction < 0)? 0.0:(fraction > 1)? 1.0: fraction;
                    fraction -= elapsed_time/(float)total_time;
                    GLib.debug("%.2f fraction", fraction );
                    uint n_time = (uint)(elapsed_time + (int)(total_time*fraction));
                    seek_time = n_time;
                    this.require_redraw = true;
                    if(released){
                        GLib.debug("time: %u", n_time);
                        this.m.MI.player_seek(n_time);
                        this.m.MI.player_play();
                        seeking = false;
                    }
                }
            }
        }
        return false;
    }
}

class VolumeBar : SDLWidget, SDLWidgetDrawing, SDLWidgetMotion
{
    private Surface button;
    private Surface bar;
    private weak Main m;
    private uint32 current_value = 0;
    private uint32 max_value = 0;
    private uint32 seek_value = 0;

	public override unowned string get_name()
	{
		return "VolumeBar";
	}
    public VolumeBar(Main m, int x, int y, int w, int h)
    {
        this.m = m;
        this.x = x; this.y  = y; this.w = w; this.h = h;

        bar = new Surface.RGB(0, w,8,32,(uint32)0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
        bar = bar.DisplayFormat();

        SDL.Rect rect = {0,0,(uint16)w,(uint16)8};
        bar.fill(rect, bar.format.map_rgb(255,255,255)); 

        rect = {1, 1,(uint16)w-2,(uint16)6};
        bar.fill(rect, bar.format.map_rgb(0,0,0)); 


        button = new Surface.RGB(0, h,h,32,(uint32)0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
        button = button.DisplayFormat();
        rect = {0,0,(uint16)h, (uint16)h};
        button.fill(rect, button.format.map_rgb(255,255,255)); 
        rect = {1,1,(uint16)h-2, (uint16)h-2};
        button.fill(rect, button.format.map_rgb(20,25,255)); 



        /* initialize */
        this.m.MI.player_status_changed.connect((source, status) => {
                var volume = status.get_volume();
                if(volume >= 0) {
                    this.max_value = 100;
                    this.current_value = volume;
                }
                GLib.debug("Volume changed: %d",volume);
                this.require_redraw = true;
                });

    }

    public void draw_drawing(Surface screen, SDL.Rect *orect)
    {
		SDL.Rect dest_rect = {0,0,0,0};
		SDL.Rect src_rect = {0,0,0,0};
        float fraction = 0.0f;

        if(max_value > 0) {
            fraction = current_value/(float)max_value;
        }
        if(seeking) {
            fraction = seek_value/(float)max_value;
        }

        dest_rect.x = (int16)this.x;
        dest_rect.y = (int16)(this.y + (this.h-8)/2);
        dest_rect.w = (uint16)this.w;
        dest_rect.h = (uint16)8;

        bar.blit_surface(null, screen, dest_rect);

        dest_rect.y = (int16)this.y;
        dest_rect.h = (uint16)this.h;
        dest_rect.x = (int16)(this.x + (this.w-this.h)*fraction);
		dest_rect.w = (uint16)this.h;
		src_rect.h = src_rect.w = (uint16)this.h;

        button.blit_surface(src_rect, screen, dest_rect);
    }

    private bool seeking = false;
    public bool motion(double x, double y, bool pushed, bool released)
    {
        if(this.inside((int)x, (int)y) || seeking)
        {
            if(pushed || seeking)
            {
                if(max_value > 0) {
                    if(!seeking) {
                        seeking = true;
                    }
                    double fraction = (x-this.x)/this.w;
                    fraction = (fraction < 0)? 0.0:(fraction > 1)? 1.0: fraction;
                    seek_value =(uint)(max_value*fraction);

                    GLib.debug("%.2f fraction", fraction );
                    if(released){
                        this.m.MI.mixer_set_volume(seek_value);
                        seeking = false;
                    }
                    this.require_redraw = true;
                }
            }
        }
        return false;
    }
    /* Avoid the click going through this widget */
    public override bool button_press()
    {
        return true;
    }
}
class PlayerControl : SDLWidget, SDLWidgetDrawing
{
    private Surface sf;
    private weak Main m;


    /* Buttons */
    public SDLMpc.Button prev_button;
    public SDLMpc.Button pause_button;
    public SDLMpc.Button next_button;
    public SDLMpc.Button stop_button;

    public VolumeBar volume_bar;

    private bool stopped = false;


	public override unowned string get_name()
	{
		return "PlayerControl";
	}
    private void previous_pressed(Button but)
    {
        SDLMpc.Event ev = new SDLMpc.Event();
        ev.type = SDLMpc.EventType.COMMANDS;
        ev.command = SDLMpc.EventCommand.PREVIOUS;
        this.m.push_event((owned)ev);
    }
    private void next_pressed(Button but)
    {
        SDLMpc.Event ev = new SDLMpc.Event();
        ev.type = SDLMpc.EventType.COMMANDS;
        ev.command = SDLMpc.EventCommand.NEXT;
        this.m.push_event((owned)ev);
    }
    private void stop_pressed(Button but)
    {
        SDLMpc.Event ev = new SDLMpc.Event();
        ev.type = SDLMpc.EventType.COMMANDS;
        ev.command = SDLMpc.EventCommand.STOP;
        this.m.push_event((owned)ev);
    }
    private void play_pressed(Button but)
    {
        SDLMpc.Event ev = new SDLMpc.Event();
        ev.type = SDLMpc.EventType.COMMANDS;
        if(stopped) {
            ev.command = SDLMpc.EventCommand.PLAY;
        }else{
            ev.command = SDLMpc.EventCommand.PAUSE;
        }
        m.push_event((owned)ev);
    }
    public void status_changed_callback(MPD.Interaction mi, MPD.Status status)
    {
        this.stopped = false;
        if(status.state == MPD.Status.State.PLAY) {
            this.pause_button.set_icon(Theme.Icons.PAUSE);
        }else {
            this.pause_button.set_icon(Theme.Icons.PLAY);
            if(status.state == MPD.Status.State.STOP){
                this.stopped = true;
            }
        }

    }
    public PlayerControl(Main m,int x, int y, int w, int h, int bpp)
    {
        this.m = m;

        this.x = x; this.y  = y; this.w = w; this.h = h;

		sf = SDLImage.load("Data/Basic/player_control.png");
		sf = sf.DisplayFormat();

        /* Previous button */
        prev_button = new SDLMpc.Button(m, (int16) this.x+ 0,(int16) this.y+0,  38, 38, null,Theme.Icons.BACKWARD);
        prev_button.b_clicked.connect(previous_pressed);

        /* Stop button */
        stop_button = new SDLMpc.Button(m, (int16) this.x+ 38,(int16) this.y+0,  38, 38, null,Theme.Icons.STOP);
        stop_button.b_clicked.connect(stop_pressed);

        /* Play/pause button */
        pause_button = new SDLMpc.Button(m,(int16) this.x+ 76,(int16) this.y+0, 38, 38, null,Theme.Icons.PLAY);
        pause_button.b_clicked.connect(play_pressed);

        next_button = new SDLMpc.Button(m, (int16) this.x+ 114,(int16) this.y+0, 38, 38, null,Theme.Icons.FORWARD);
        next_button.b_clicked.connect(next_pressed);

        m.MI.player_status_changed.connect(status_changed_callback);
        volume_bar = new VolumeBar(m, (int16) this.x+ 280,(int16) this.y+10,(uint16)(this.w-300), 20);

        this.children.append(prev_button);
        this.children.append(stop_button);
        this.children.append(pause_button);
        this.children.append(next_button);
        this.children.append(volume_bar);
    }
    public void draw_drawing(Surface screen, SDL.Rect *orect)
    {
        SDL.Rect dest_rect = {0,0,0,0};
        SDL.Rect src_rect = {0,0,0,0};

        src_rect.x = int16.max((int16)(orect.x-this.x),0);
        src_rect.y = int16.max((int16)(orect.y-this.y), 0);
        src_rect.w = uint16.min(orect.w,(uint16)this.w);
        src_rect.h = uint16.min(orect.h,(uint16)this.h);


        dest_rect.x = (int16)(src_rect.x+this.x);
        dest_rect.y = (int16)(src_rect.y+this.y);
        dest_rect.w = (int16)(src_rect.w);
        dest_rect.h = (int16)(src_rect.h);
        
        sf.blit_surface(src_rect, screen, dest_rect);
    }


    /**
     * Player control claims several buttons.
     * And handles these
     */
    public override bool Event(SDLMpc.Event ev)
    {
        if(ev.type == SDLMpc.EventType.KEY) {
            switch(ev.command)
            {
                case EventCommand.PAUSE:
                case EventCommand.NEXT:
                case EventCommand.PLAY:
                case EventCommand.PREVIOUS:
                    var pev = ev.Copy(); 
                    pev.type = SDLMpc.EventType.COMMANDS;
                    m.push_event((owned)pev);
                    return true;
                default:
                    break;
            }
        }
        return false;
    }

}
