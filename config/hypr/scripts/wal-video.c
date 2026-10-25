/*
 * wal-video.c - Lightweight Wayland Layer-Shell Video Wallpaper Daemon for Hyprland
 * Uses gtk-layer-shell-0 + Cairo + FFmpeg hardware-accelerated decoding pipe.
 * Compile: gcc -O2 wal-video.c -o wal-video $(pkg-config --cflags --libs gtk+-3.0 gtk-layer-shell-0)
 */

#include <gtk/gtk.h>
#include <gtk-layer-shell/gtk-layer-shell.h>
#include <cairo.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <signal.h>
#include <unistd.h>

static int width = 1920;
static int height = 1080;
static uint8_t *frame_buf = NULL;
static cairo_surface_t *surface = NULL;
static FILE *ffmpeg_pipe = NULL;
static GtkWidget *drawing_area = NULL;
static char *video_path = NULL;

static void start_ffmpeg_pipe(void) {
    if (ffmpeg_pipe) {
        pclose(ffmpeg_pipe);
        ffmpeg_pipe = NULL;
    }
    char cmd[4096];
    snprintf(
        cmd, sizeof(cmd),
        "ffmpeg -nostdin -loglevel quiet -stream_loop -1 -re -hwaccel auto -i \"%s\" "
        "-vf \"scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d,fps=30\" "
        "-f rawvideo -pix_fmt bgra -",
        video_path, width, height, width, height
    );
    ffmpeg_pipe = popen(cmd, "r");
}

static gboolean on_tick(gpointer user_data) {
    (void)user_data;
    if (!ffmpeg_pipe || !frame_buf) {
        return G_SOURCE_CONTINUE;
    }

    size_t frame_bytes = (size_t)width * (size_t)height * 4;
    size_t total_read = 0;
    while (total_read < frame_bytes) {
        size_t n = fread(frame_buf + total_read, 1, frame_bytes - total_read, ffmpeg_pipe);
        if (n == 0) {
            /* EOF or error: restart loop */
            start_ffmpeg_pipe();
            return G_SOURCE_CONTINUE;
        }
        total_read += n;
    }

    cairo_surface_mark_dirty(surface);
    if (drawing_area) {
        gtk_widget_queue_draw(drawing_area);
    }
    return G_SOURCE_CONTINUE;
}

static gboolean on_draw(GtkWidget *widget, cairo_t *cr, gpointer user_data) {
    (void)widget;
    (void)user_data;
    if (surface) {
        cairo_set_source_surface(cr, surface, 0, 0);
        cairo_paint(cr);
    }
    return FALSE;
}

static void cleanup(int sig) {
    (void)sig;
    if (ffmpeg_pipe) {
        pclose(ffmpeg_pipe);
        ffmpeg_pipe = NULL;
    }
    exit(0);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <video.mp4>\n", argv[0]);
        return 1;
    }
    video_path = argv[1];

    signal(SIGINT, cleanup);
    signal(SIGTERM, cleanup);

    gtk_init(&argc, &argv);

    GdkDisplay *display = gdk_display_get_default();
    if (display) {
        GdkMonitor *mon = gdk_display_get_primary_monitor(display);
        if (!mon && gdk_display_get_n_monitors(display) > 0) {
            mon = gdk_display_get_monitor(display, 0);
        }
        if (mon) {
            GdkRectangle geom;
            gdk_monitor_get_geometry(mon, &geom);
            if (geom.width > 0 && geom.height > 0) {
                width = geom.width;
                height = geom.height;
            }
        }
    }

    frame_buf = calloc((size_t)width * (size_t)height, 4);
    if (!frame_buf) {
        return 1;
    }

    surface = cairo_image_surface_create_for_data(
        frame_buf, CAIRO_FORMAT_RGB24, width, height, width * 4
    );

    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_layer_init_for_window(GTK_WINDOW(window));
    gtk_layer_set_layer(GTK_WINDOW(window), GTK_LAYER_SHELL_LAYER_BACKGROUND);
    gtk_layer_set_namespace(GTK_WINDOW(window), "wal-video");
    gtk_layer_set_exclusive_zone(GTK_WINDOW(window), -1);
    gtk_layer_set_anchor(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_TOP, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(window), GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);

    gtk_widget_set_size_request(window, width, height);
    gtk_widget_set_app_paintable(window, TRUE);

    drawing_area = gtk_drawing_area_new();
    gtk_widget_set_size_request(drawing_area, width, height);
    g_signal_connect(G_OBJECT(drawing_area), "draw", G_CALLBACK(on_draw), NULL);
    gtk_container_add(GTK_CONTAINER(window), drawing_area);

    start_ffmpeg_pipe();
    /* 33ms timer (~30 FPS) synced with ffmpeg -re */
    g_timeout_add(33, on_tick, NULL);

    gtk_widget_show_all(window);
    gtk_main();

    cleanup(0);
    return 0;
}
