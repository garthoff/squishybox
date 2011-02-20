/**
 * Testing
 *
 * Todo list:
 * 
 *  # Create a set of fixed font sizes widgets can use.
 *  # Make better scrolling by touch.
 *  # Fix event handling.
 *
 */

using SDL;
using SDLTTF;
using SDLImage;
using MPD;
using Posix;
using SDLMpc;

namespace SDLMpc
{
    public string format_song_title(MPD.Song song)
	{
		string retv = "";
		int i=0;
		string a;
		for(i=0;(a = song.get_tag(MPD.Tag.Type.TITLE,i)) != null; i++) {
			if(i > 0)
				retv += ", "+a;
			else
				retv = a;

		}
		if(i == 0) {
			retv = GLib.Path.get_basename(song.uri);

		}

		return retv;
	}



    public enum FontSize
    {
        TINY,
            SMALL,
            NORMAL,
            LARGE,
            VERY_LARGE,
            NUM_FONTS
    }

    class Main : GLib.Object
    {
        public Font fonts[5/*FontSize.NUM_FONTS*/];
        /**
         * The main screen
         */
        private unowned Screen screen;

        /**
         * MPD Interaction object.
         */
        public MPD.Interaction MI = new MPD.Interaction();

        /**
         * The mainloop
         */
        private GLib.MainLoop loop = new GLib.MainLoop();

        private SDLWidget bg;
        private SDLWidget selector;
        private SDLWidget header;
        private Standby standby;
        /**
         * Object to set backlight
         */
        public DisplayControl display_control = new DisplayControl();
        private Surface sf = null;

        private double old_pos_x = 0.0;
        private double old_pos_y = 0.0;


        /**
         * Main event queue
         * Event queue.
         */
        private Queue<SDLMpc.Event> events= new Queue<SDLMpc.Event>();

        /**
         * Add push event
         */
        public void push_event(owned SDLMpc.Event event)
        {
            events.push_tail((owned)event);
        }



        /**
         * run the main loop
         */
        public void run()
        {
            GLib.debug("Run mainloop");
            loop.run();
        }


        /* Constructor */
        public Main()
        {
            /* Initialize SDL */
            GLib.debug("SDL.init");
            SDL.init(SDL.InitFlag.VIDEO);
            /* Initialize font system */
            GLib.debug("SDLTTF.init");
            SDLTTF.init();


            /**
             * Set unicode support 
             */
            SDL.Key.enable_unicode(1);
            /**
             * Set key repeat 
             */
            SDL.Key.set_repeat(100,10);

            /**
             * Setup the screen. This is different for PC 
             * and embedded mode 
             */
            GLib.debug("Set Video mode");

#if PC
            /* Set doublebuffered and hw, not fullscreen */
            screen = SDL.Screen.set_video_mode(
                    480,
                    272,
                    32,
                    SDL.SurfaceFlag.DOUBLEBUF|SDL.SurfaceFlag.HWSURFACE);
#else
            /* Disable the cursor */
            SDL.Cursor.show(0);
            /* Setup fullscreen video mode */
            screen = SDL.Screen.set_video_mode(
                    480,
                    272,
                    32,
                   /* SDL.SurfaceFlag.DOUBLEBUF|*/
                   SDL.SurfaceFlag.ASYNCBLIT|
                    SDL.SurfaceFlag.HWSURFACE|
                    SDL.SurfaceFlag.FULLSCREEN);
#endif

            sf = new Surface.RGB(0, 480,272,32,(uint32)0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
            sf = sf.DisplayFormat();

            fonts[FontSize.TINY] = new Font("test.ttf", 10);
            fonts[FontSize.SMALL] = new Font("test.ttf", 20);
            fonts[FontSize.NORMAL] = new Font("test.ttf", 30);
            fonts[FontSize.LARGE] = new Font("test.ttf", 40);
            fonts[FontSize.VERY_LARGE] = new Font("test.ttf", 50);

            /* Error check */
            if(screen == null) {
                GLib.error("failed to create screen\n");
            }

            /* Create background drawer */
            GLib.debug("Create background draw object");


            /* Prepare basic widget */
            /* Create a background widget that always draws the background */
            bg       = new BackgroundDrawer  (this,  0,      0,  480, 272, 32);

            /* Main menu */
            selector = new Selector (this,  0,      38,  480, 234, 32);

            /* Add items */
            (selector as Selector).add_item(new NowPlaying      (this, 0, 38,  480, 234, 32));
            (selector as Selector).add_item(new MpdPlaylistView (this, 0, 38,  480, 234, 32));
            (selector as Selector).add_item(new MpdDatabaseView (this, 0, 38,  480, 234, 32,null));
            (selector as Selector).add_item(new ServerMenu      (this, 0, 38,  480, 234, 32));
            (selector as Selector).add_item(new AlarmTimer      (this, 0, 38,  480, 234, 32));
            standby = new Standby(this);


            /* Add main selector to background */
            bg.children.append(selector);

            /* Add the header part by default. */
            /* 480 pixels width, 38 high */
            header = new Header (this, 0, 0, 480, 38,32);
            bg.children.append(header);


            /* Add interface update timeout, 10fps */
            GLib.debug("Add timeout");
            GLib.Timeout.add(1000/10, main_draw);

            GLib.debug("Connect to mpd");
            MI.mpd_connect();
        }

        /**
         * Quit
         */
        ~Main()
        {

            GLib.debug("Running SDL.quit()");
            SDL.quit();
        }

        /**
         * Main loop itteration
         */
        private bool main_draw()
        {
            bool cc = false;

            SDL.Event event = SDL.Event();
            SDLMpc.Event ev; 

            /* Clear the screen */
            time_t now = time_t();
            standby.Tick(now);
            bg.do_Tick(now);


            List<SDL.Rect?> rr = null;
            SDL.Rect g = {0,0,0,0};
            rr = bg.get_redraw_rect((owned)rr,g);

            g.x = 0; g.y = 0; g.w = 480; g.h = 272;
#if SHOW_REDRAW
            var rsf = new Surface.RGB(0, 480,272,32,(uint32)0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF);
            rsf.fill(g, sf.format.map_rgba(130,30,130,128)); 
            rsf  = rsf.DisplayFormatAlpha();
#endif
			if(rr != null) 
            {
				foreach ( SDL.Rect rect in rr)
				{
					bg.draw(sf,&rect);
				}
				cc = true;
                /* Custom double buffering */
                sf.blit_surface(g, screen,g);
#if SHOW_REDRAW
                foreach ( SDL.Rect rect in rr) {
                    rsf.blit_surface(rect, screen,rect);
                }
#endif
                /* Not needed on SBT? */
                screen.update_rect(0,0,480,272);
			}
            /** 
             * Translate SDL Events 
             * TODO: Move this to an SDLEvent file
             */
            while(SDL.Event.poll(event)>0){
                switch(event.type)
                {
                    case SDL.EventType.MOUSEMOTION:
                        if(event.motion.state > 0)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.MOUSE_MOTION;
                            ev.motion.x = event.motion.x;
                            ev.motion.y = event.motion.y;
                            push_event((owned)ev);
                        }
                        break;
                    case SDL.EventType.MOUSEBUTTONDOWN:
                        ev = new SDLMpc.Event();
                        ev.type = SDLMpc.EventType.MOUSE_MOTION;
                        ev.motion.x = event.motion.x;
                        ev.motion.y = event.motion.y;
                        ev.motion.pushed = true;
                        push_event((owned)ev);
                        break;
                    case SDL.EventType.MOUSEBUTTONUP:
                        ev = new SDLMpc.Event();
                        ev.type = SDLMpc.EventType.MOUSE_MOTION;
                        ev.motion.x = event.motion.x;
                        ev.motion.y = event.motion.y;
                        ev.motion.released = true;
                        push_event((owned)ev);
                        break;
                    case SDL.EventType.QUIT:
                        ev = new SDLMpc.Event();
                        ev.type = SDLMpc.EventType.COMMANDS;
                        ev.command = EventCommand.QUIT;
                        push_event((owned)ev);
                        break;
                    case SDL.EventType.KEYDOWN:
                        if(event.key.keysym.sym == 49)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.K_1;
                            push_event((owned)ev);
                        }
                        if(event.key.keysym.sym == 50)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.K_2;
                            push_event((owned)ev);
                        }
                        if(event.key.keysym.sym == 51)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.K_3;
                            push_event((owned)ev);
                        }
                        if(event.key.keysym.sym == 52)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.K_4;
                            push_event((owned)ev);
                        }
                        if(event.key.keysym.sym == 53)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.K_5;
                            push_event((owned)ev);
                        }
                        if(event.key.keysym.sym == 54) 
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.K_6;
                            push_event((owned)ev);
                        }
                        if(event.key.keysym.sym == 55) 
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.K_7;
                            push_event((owned)ev);
                        }
                        if(event.key.keysym.sym == 56) 
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.K_8;
                            push_event((owned)ev);
                        }
                        if(event.key.keysym.sym == 57) 
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.K_9;
                            push_event((owned)ev);
                        }
                        if(event.key.keysym.sym == 48)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.K_0;
                            push_event((owned)ev);
                        }
                        if(event.key.keysym.sym == KeySymbol.q)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.COMMANDS;
                            ev.command = EventCommand.QUIT;
                            push_event((owned)ev);
                        }
                        else if (event.key.keysym.sym == KeySymbol.h)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.BROWSE;
                            push_event((owned)ev);
                        }
                        else if (event.key.keysym.sym == KeySymbol.z)
                        {
                            GLib.debug("insert z event");
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.PREVIOUS;
                            push_event((owned)ev);
                        }
                        else if (event.key.keysym.sym == KeySymbol.UP)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.UP;
                            push_event((owned)ev);
                        }
                        else if (event.key.keysym.sym == KeySymbol.DOWN)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.DOWN;
                            push_event((owned)ev);
                        }
                        else if (event.key.keysym.sym == KeySymbol.RIGHT)
                        {
                            ev = new SDLMpc.Event();
                            ev.type = SDLMpc.EventType.KEY;
                            ev.command = EventCommand.RIGHT;
                            push_event((owned)ev);
                        }
                        break;
                    default:
                        break;

                }
            }


            /**
             * Internal Event Queue 
             */
             if(events.length > 0) 
             { 
                if(!this.standby.Wakeup()) {
                    events.clear();
                }
             }
             while((ev= events.pop_head()) != null)
            {
                if(ev.type == SDLMpc.EventType.INVALID) 
                    continue;
                if(ev.type == SDLMpc.EventType.KEY) {
                    switch(ev.command) {
                        case EventCommand.SLEEP:
                            {
                                var b = display_control.getBrightness();
                                if(b == 255)
                                    b = 55;
                                else 
                                    b+=50;
                                display_control.setBrightness(b);
                            }
                            break;
                        case EventCommand.POWER:
                        {
                            events.clear();
                            this.standby.activate();
                        }
                        break;
                        default:
                            /* Forward */
                            bg.do_Event(ev);
                            break;
                    }
                }
                /* Handle incoming remote events */
                else if(ev.type == SDLMpc.EventType.COMMANDS) {
                    switch(ev.command) {
                        case EventCommand.QUIT:
                            GLib.debug("request quit");
                            MI = null;
                            bg = null;
                            (selector as Selector).clear();
                            selector = null;
                            display_control = null;
                            loop.quit();
                            loop = null;
                            return false;
                        case EventCommand.PAUSE:
                            MI.player_toggle_pause(); 
                            break;
                        case EventCommand.NEXT:
                            MI.player_next();
                            break;
                        case EventCommand.PREVIOUS:
                            MI.player_previous();
                            break;
                        case EventCommand.PLAY:
                            MI.player_play();
                            break;
                        case EventCommand.STOP:
                            MI.player_stop();
                            break;
                        case EventCommand.POWER:
                            if(!this.standby.is_standby)
                                this.standby.activate();
                            break;

                        default:
                            bg.do_Event(ev);
                            break;
                    }
                }
                else if(ev.type == SDLMpc.EventType.MOUSE_MOTION) {
                    if(ev.motion.pushed) {
                        old_pos_x =  ev.motion.x;
                        old_pos_y =  ev.motion.y;
                        GLib.debug("push %.2f %.2f", ev.motion.x, ev.motion.y); 

                        bg.do_Motion(ev.motion.x, ev.motion.y, ev.motion.pushed, ev.motion.released);
                        bg.clicked((int16)old_pos_x,(int16) old_pos_y, true);
                    }
                    else if (ev.motion.released) {
                        bg.do_Motion(old_pos_x, old_pos_y, ev.motion.pushed, ev.motion.released);
                        bg.clicked((int16)old_pos_x,(int16) old_pos_y, false);
                        old_pos_x = 0;
                        old_pos_y = 0;
                        /* Make sure there is a correct pos on release */
                        GLib.debug("push release %.2f %.2f", ev.motion.x, ev.motion.y); 
                    } else {
                        bg.do_Motion(ev.motion.x, ev.motion.y, ev.motion.pushed, ev.motion.released);
                        old_pos_x = ev.motion.x;
                        old_pos_y = ev.motion.y;
                    }
                }
                else {
                    GLib.debug("Key event");
                    bg.do_Event(ev);
                }

            }
            if(cc){
                //screen.flip();
            }
            return true;
        }
    }
}




/**
 * param argv the command line arguments
 *
 * The entry point of the program  
 */
static int main (string[] argv)
{
    GLib.debug("Starting main");
    GLib.Intl.setlocale(GLib.LocaleCategory.TIME, "nl_NL.UTF8");
    /* Create Main object */
    Main m = new Main();
    /* Infrared input event handling. */
    IREvent e  = new IREvent(m);
    /* Touchscreen input event handling */
    TCEvent tc = new TCEvent(m);
    /* Run */
    GLib.debug("Run main loop");
    /* Run the main loop */
    m.run();
    /* Cleanup */
    e = null;
    tc = null;
    SDL.quit();

    return 0;
}
