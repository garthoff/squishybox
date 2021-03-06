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
using SDLMpc;
using SDLTTF;

/**
 * This implements a stanby function.
 * The box has no real standby, so it will just turn off the backlight and stop playback.
 * 
 * * Standby -> button press
 * * Standby -> 1 minute playback stopped.
 * * Wakeup -> button press
 * * Wakeup -> playback start
 * * Wakeup -> moving close to squeezebox
 */

class Standby 
{
    private Main m;
    public bool is_standby {get; set; default = false;}
    private time_t off_time = 0;
    private time_t on_time = time_t();
    private bool playing = false;

    /**
     * Time tick from the mainloop 
     */
    public void Tick (time_t t)
    {
        /* if we are one minute 'idle', turn off screen */
        if(!playing && (t-on_time) > 60) {
            if(!this.is_standby)
                this.activate();
        }
    }
    /* Constructor */
    public Standby(Main m)
    {
        this.m = m;

        m.MI.player_status_changed.connect((source, status) => 
        {
            Wakeup();
            if((status.state == MPD.Status.State.PLAY ||
                    status.state == MPD.Status.State.PAUSE) 
                    )
                {
                    playing = true;
                }else{
                    playing = false;
                }
        });
    }

    /* Wake the box up */
    public bool Wakeup()
    {
        if(this.is_standby)
        {
            if(time_t() -off_time > 1)
            {
                GLib.debug("wakeup");
                turn_display_on();
                this.is_standby = false;
            }
            else return false;
        }
        on_time = time_t();
        return true;
    }

    /* Go into standby */
    public void activate()
    {
        var ev = new SDLMpc.Event();
        ev.type = SDLMpc.EventType.COMMANDS;
        ev.command = EventCommand.STOP;
        m.push_event((owned)ev);

        turn_display_off();
        is_standby = true;
        off_time = time_t();
    }

    private void turn_display_off()
    {
        this.m.display_control.setEnabled(false);
    }
    private void turn_display_on()
    {
        this.m.display_control.setEnabled(true);
    }
}

