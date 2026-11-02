// Headless integration test using real libobs, its Lua binding and OpenGL.
#define _GNU_SOURCE
#include <obs.h>
#include <obs-module.h>
#include <obs-nix-platform.h>
#include <graphics/graphics.h>
#include <graphics/vec4.h>
#include <util/platform.h>
#include <X11/Xlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <execinfo.h>
#include <ucontext.h>
#include <dlfcn.h>
static void crash(int sig,siginfo_t *si,void *ctx){
    ucontext_t *uc=ctx;void *ip=(void *)uc->uc_mcontext.gregs[REG_RIP];Dl_info di={0};dladdr(ip,&di);
    fprintf(stderr,"SIGNAL %d addr=%p ip=%p lib=%s symbol=%s\n",sig,si->si_addr,ip,di.dli_fname?di.dli_fname:"?",di.dli_sname?di.dli_sname:"?");
    void *trace[40];int n=backtrace(trace,40);backtrace_symbols_fd(trace,n,2);_Exit(128+sig);
}

typedef struct obs_script obs_script_t;
extern bool obs_scripting_load(void);
extern void obs_scripting_unload(void);
extern obs_script_t *obs_script_create(const char *, obs_data_t *);
extern void obs_script_destroy(obs_script_t *);
extern bool obs_script_loaded(const obs_script_t *);
extern bool obs_script_reload(obs_script_t *);
extern obs_properties_t *obs_script_get_properties(obs_script_t *);
extern void obs_script_update(obs_script_t *, obs_data_t *);

static gs_texture_t *pattern;
static int width=320,height=180;
static const char *get_name(void *p) {return "Test pattern";}
static void *create(obs_data_t *s,obs_source_t *source){return source;}
static void source_destroy(void *p) {}
static uint32_t get_width(void *p){return width;}
static uint32_t get_height(void *p){return height;}
static void video_render(void *p,gs_effect_t *e) {obs_source_draw(pattern,0,0,width,height,false);}
static void make_pattern(int phase) {
    uint8_t *px=malloc(width*height*4);
    for(int y=0;y<height;y++) for(int x=0;x<width;x++) {
        int at=(y*width+x)*4;
        px[at]=(x+phase)%256;px[at+1]=y*255/height;
        px[at+2]=((x/20+y/20+phase/10)%2)*200+20;
        px[at+3]=(x<12||x>width-12||y<8||y>height-8)?128:255;
    }
    if(pattern)gs_texture_destroy(pattern);
    const uint8_t *data=px;
    pattern=gs_texture_create(width,height,GS_RGBA,1,&data,0);
    free(px);
}
static unsigned long render_frame(obs_source_t *source,const char *file) {
    obs_enter_graphics();
    gs_texrender_t *rt=gs_texrender_create(GS_RGBA,GS_ZS_NONE);
    gs_stagesurf_t *stage=gs_stagesurface_create(width,height,GS_RGBA);
    if(!gs_texrender_begin(rt,width,height)){fprintf(stderr,"Target failed\n");exit(5);}
    struct vec4 clear={0};gs_clear(GS_CLEAR_COLOR,&clear,0,0);
    gs_ortho(0,width,0,height,-100,100);
    obs_source_video_render(source);
    gs_texrender_end(rt);
    gs_stage_texture(stage,gs_texrender_get_texture(rt));
    uint8_t *bytes;uint32_t pitch;
    unsigned long sum=0;
    if(gs_stagesurface_map(stage,&bytes,&pitch)) {
        FILE *fp=file?fopen(file,"wb"):NULL;
        if(fp)fprintf(fp,"P6\n%d %d\n255\n",width,height);
        for(int y=0;y<height;y++)for(int x=0;x<width;x++) {
            uint8_t *p=bytes+y*pitch+x*4;
            sum+=p[0]+p[1]+p[2];
            if(fp)fwrite(p,1,3,fp);
        }
        if(fp)fclose(fp);
        gs_stagesurface_unmap(stage);
    }
    gs_stagesurface_destroy(stage);gs_texrender_destroy(rt);
    obs_leave_graphics();
    return sum;
}
int main(int argc,char **argv) {
    struct sigaction sa={.sa_sigaction=crash,.sa_flags=SA_SIGINFO};sigaction(SIGSEGV,&sa,NULL);setvbuf(stdout,NULL,_IONBF,0);
    const char *prefix=argv[1],*script_path=argv[2],*outdir=argv[3];
    char graphics[2048],data[2048];
    snprintf(graphics,sizeof graphics,"%s/usr/lib/x86_64-linux-gnu/libobs-opengl.so",prefix);
    snprintf(data,sizeof data,"%s/usr/share/obs/libobs",prefix);
    Display *display=XOpenDisplay(NULL);
    if(!display){fprintf(stderr,"No X display\n");return 2;}
    obs_set_nix_platform(OBS_NIX_PLATFORM_X11_EGL);obs_set_nix_platform_display(display);
    if(!obs_startup("en-US",NULL,NULL))return 2;
    obs_add_data_path(data);
    struct obs_video_info vi={.graphics_module=graphics,.fps_num=30,.fps_den=1,.base_width=1280,.base_height=720,
        .output_width=1280,.output_height=720,.output_format=VIDEO_FORMAT_RGBA,.adapter=0,.gpu_conversion=false,
        .colorspace=VIDEO_CS_709,.range=VIDEO_RANGE_FULL,.scale_type=OBS_SCALE_BILINEAR};
    int ret=obs_reset_video(&vi);if(ret){fprintf(stderr,"Video init failed: %d\n",ret);return 3;}
    if(!obs_scripting_load()){fprintf(stderr,"Scripting init failed\n");return 3;}
    obs_script_t *script=obs_script_create(script_path,NULL);
    if(!script||!obs_script_loaded(script)){fprintf(stderr,"Script load failed\n");return 4;}
    if(getenv("LITEYEAR_SMOKE")){obs_script_destroy(script);obs_scripting_unload();obs_shutdown();puts("SMOKE_PASS");return 0;}
    struct obs_source_info input={.id="liteyear_pattern",.type=OBS_SOURCE_TYPE_INPUT,.output_flags=OBS_SOURCE_VIDEO,
        .get_name=get_name,.create=create,.destroy=source_destroy,.get_width=get_width,.get_height=get_height,.video_render=video_render};
    obs_register_source(&input);
    obs_source_t *source=obs_source_create_private("liteyear_pattern","Pattern",NULL);
    obs_enter_graphics();make_pattern(0);obs_leave_graphics();
    char path[4096];snprintf(path,sizeof path,"%s/original.ppm",outdir);
    unsigned long baseline=render_frame(source,path);fprintf(stdout,"BASELINE %lu\n",baseline);
    const char *ids[]={"ca","skip","interlace","poster","dither","crt","ntsc","boot","matrix","codec","vhs","bloom","scan","digital","analog"};
    int fail=0;
    for(int i=0;i<15;i++) {
        char id[100];snprintf(id,sizeof id,"liteyear_retro_%s_v1",ids[i]);
        obs_source_t *filter=obs_source_create_private(id,ids[i],NULL);
        if(!filter){fprintf(stdout,"FAIL_CREATE %s\n",ids[i]);fail++;continue;}
        obs_properties_t *props=obs_source_properties(filter);obs_properties_destroy(props);
        obs_source_filter_add(source,filter);
        unsigned long sum=0;
        for(int frame=0;frame<4;frame++) {
            os_sleep_ms(40);
            snprintf(path,sizeof path,"%s/%s.ppm",outdir,ids[i]);
            sum=render_frame(source,frame==3?path:NULL);
        }
        if(sum==0 || ((sum==baseline)&&i!=1&&i!=7)) {fprintf(stdout,"FAIL_OUTPUT %s %lu\n",ids[i],sum);fail++;}
        else fprintf(stdout,"PASS %s %lu\n",ids[i],sum);
        // Exercise every exposed dropdown through OBS's actual property API.
        props=obs_source_properties(filter);
        for(obs_property_t *p=obs_properties_first(props);p;obs_property_next(&p)) {
            if(obs_property_get_type(p)!=OBS_PROPERTY_LIST)continue;
            const char *name=obs_property_name(p);
            if(i==5 || i==4)continue; // compile permutations below
            for(size_t index=0;index<obs_property_list_item_count(p);index++) {
                obs_data_t *s=obs_source_get_settings(filter);
                obs_data_set_int(s,name,obs_property_list_item_int(p,index));
                obs_source_update(filter,s);obs_data_release(s);os_sleep_ms(45);
                unsigned long v=render_frame(source,NULL);
                if(!v){fprintf(stdout,"FAIL_OPTION %s %s %zu\n",ids[i],name,index);fail++;}
            }
        }
        obs_properties_destroy(props);
        if((i==5 || i==4) && !getenv("LITEYEAR_FAST")) {
            int max=i==5?24:8;
            for(int value=0;value<=max;value++) {
                if(i==4 && value!=0 && value!=2 && value!=4 && value!=8)continue;
                obs_data_t *s=obs_source_get_settings(filter);
                obs_data_set_int(s,i==5?"mask":"pattern",value);
                obs_source_update(filter,s);obs_data_release(s);os_sleep_ms(40);
                unsigned long v=render_frame(source,NULL);
                if(v==0){fprintf(stdout,"FAIL_VARIANT %s %d\n",ids[i],value);fail++;}
            }
        }
        if(i==1) {
            obs_data_t *s=obs_source_get_settings(filter);obs_data_set_int(s,"frames",30);
            obs_source_update(filter,s);obs_data_release(s);os_sleep_ms(40);
            unsigned long hold1=render_frame(source,NULL);
            obs_enter_graphics();make_pattern(60);obs_leave_graphics();os_sleep_ms(40);
            unsigned long hold2=render_frame(source,NULL);
            fprintf(stdout,"FRAME_HOLD %lu %lu\n",hold1,hold2);
            if(hold1!=hold2)fail++;
            obs_enter_graphics();make_pattern(0);obs_leave_graphics();
        }
        // Resolution changes must reset temporal buffers and retain output.
        width=400;height=224;obs_enter_graphics();make_pattern(20);obs_leave_graphics();os_sleep_ms(40);
        if(!render_frame(source,NULL)){fprintf(stdout,"FAIL_RESIZE %s\n",ids[i]);fail++;}
        width=320;height=180;obs_enter_graphics();make_pattern(0);obs_leave_graphics();
        obs_source_filter_remove(source,filter);obs_source_release(filter);
    }
    // A persisted settings round trip and source stack survive script reload.
    obs_source_t *fx1=obs_source_create_private("liteyear_retro_scan_v1","Stack scan",NULL);
    obs_source_t *fx2=obs_source_create_private("liteyear_retro_ca_v1","Stack CA",NULL);
    obs_source_filter_add(source,fx1);obs_source_filter_add(source,fx2);os_sleep_ms(60);
    unsigned long before=render_frame(source,NULL);
    obs_data_t *state=obs_source_get_settings(fx1);
    const char *json=obs_data_get_json(state);obs_data_t *roundtrip=obs_data_create_from_json(json);
    obs_source_update(fx1,roundtrip);obs_data_release(roundtrip);obs_data_release(state);
    if(!getenv("LITEYEAR_NO_RELOAD") && !obs_script_reload(script)){fprintf(stdout,"FAIL_RELOAD\n");fail++;}
    os_sleep_ms(80);unsigned long after=render_frame(source,NULL);
    fprintf(stdout,"STACK_RELOAD %lu %lu\n",before,after);if(!after)fail++;
    obs_data_t *script_settings=obs_data_create();obs_data_set_bool(script_settings,"bypass",true);obs_script_update(script,script_settings);obs_data_release(script_settings);
    os_sleep_ms(50);unsigned long bypass=render_frame(source,NULL);
    fprintf(stdout,"BYPASS %lu baseline=%lu\n",bypass,baseline);if(bypass!=baseline)fail++;
    // Exercise diagnostic and reload buttons through the host property callbacks.
    obs_properties_t *sp=obs_script_get_properties(script);
    obs_property_button_clicked(obs_properties_get(sp,"check"),script);
    obs_property_button_clicked(obs_properties_get(sp,"reload"),script);
    obs_properties_destroy(sp);
    obs_source_filter_remove(source,fx2);obs_source_filter_remove(source,fx1);obs_source_release(fx1);obs_source_release(fx2);
    fprintf(stdout,"CLEANUP source\n");obs_source_release(source);
    fprintf(stdout,"CLEANUP queue\n");
    obs_wait_for_destroy_queue();
    fprintf(stdout,"CLEANUP texture\n");obs_enter_graphics();gs_texture_destroy(pattern);pattern=NULL;obs_leave_graphics();
    fprintf(stdout,"CLEANUP script\n");obs_script_destroy(script);
    fprintf(stdout,"CLEANUP scripting\n");obs_scripting_unload();
    fprintf(stdout,"CLEANUP OBS\n");obs_shutdown();
    fprintf(stdout,"FAILURES %d\n",fail);
    return fail?1:0;
}
