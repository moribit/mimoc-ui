// Host-only oracle. Includes the pinned, unmodified Mo-Bus renderers.
// No transport, display bus, network, or firmware is initialized.
#include <LovyanGFX.hpp>
#include <lgfx/v1/panel/Panel_SSD1306.hpp>
#include <ctime>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <filesystem>
#include <display/renderer/menu_renderer.hpp>
#include <display/renderer/contact_renderer.hpp>
#include <display/renderer/open_chat_renderer.hpp>
#include <ui/widgets/confirm_dialog.hpp>
#include "confirm_capture.inc"
#include "setting_capture.inc"

extern "C" time_t time(time_t* p) {
    const time_t fixed = 1780317296; // 2026-06-01 12:34:56 UTC
    if (p) *p = fixed;
    return fixed;
}

// Use the original OLED conversion and rotation code, replacing only bus I/O.
struct MemoryOLED : lgfx::Panel_SSD1306 {
    MemoryOLED() { _buf = static_cast<uint8_t*>(calloc(1024, 1)); setRotation(2); }
    void beginTransaction() override {}
    void endTransaction() override {}
    void display(uint_fast16_t, uint_fast16_t, uint_fast16_t, uint_fast16_t) override {}
};

void save(lgfx::LGFX_Sprite& s, const std::string& path) {
    MemoryOLED panel;
    lgfx::LGFX_Device device;
    device.setPanel(&panel);
    device.setRotation(2);
    s.pushSprite(&device, 0, 0);
    uint8_t data[1024] = {};
    for (int y=0;y<64;y++) for(int x=0;x<128;x++)
        if(device.readPixel(x,y)) data[(y/8)*128+x] |= 1 << (y%8);
    std::ofstream(path, std::ios::binary).write(reinterpret_cast<char*>(data),1024);
}

int main(int argc, char** argv) {
    if(argc != 2) return 2;
    const std::string out = argv[1];
    setenv("TZ", "UTC", 1); tzset();
    std::filesystem::create_directories(out);
    auto frame = [&](const char* name, auto render) {
        sprite.deleteSprite(); sprite.setColorDepth(8); sprite.createSprite(128,64);
        sprite.setTextSize(1); sprite.setTextDatum(lgfx::textdatum_t::top_left);
        sprite.setTextWrap(false); sprite.setTextColor(0xffff,0); sprite.setCursor(0,0);
        render();
        std::string filename=name; for(auto& c:filename)if(c=='/')c='-';
        save(sprite,out+"/"+filename+".raw");
    };
    for(int variant=0;variant<4;variant++) {
        const char* names[]={"menu/default","menu/selected-settings","menu/notification","menu/radio-offline"};
        frame(names[variant],[&] {
            ui::menu::ViewState v; v.cursor_index=variant==1?1:0; v.radio_level=3;
            v.radio_available=variant!=3; v.battery_percent=73; v.has_notification=variant==2;
            ui::menu::Renderer().render(v,display::renderer::make_menu_render_api(sprite,{},[]{}));
        });
    }
    for(int variant=0;variant<6;variant++) {
        const char* names[]={"contacts/default","contacts/pending","contacts/unread","contacts/mode-cq","contacts/mode-focused","contacts/loading"};
        frame(names[variant],[&] {
            ui::contactbook::ViewState v;
            for(int i=0;i<10;i++) { ui::contactbook::RowData row; row.label=i==0?"Hazuki":"Taro"; v.rows.push_back(row); }
            v.rows[0].is_pending=variant==1; v.rows[0].has_unread=variant==2;
            v.chat_mode=variant==3?ui::contactbook::ChatMode::Cq:ui::contactbook::ChatMode::Qsp;
            v.mode_focused=variant==4;
            if(variant==5){v.rows.resize(1);v.rows[0].label="Loading";v.loading=true;}
            ui::contactbook::Renderer().render(v,display::renderer::make_contact_book_render_api(sprite,v,[]{}));
        });
    }
    for(int variant=0;variant<4;variant++) {
        const char* names[]={"chat/default","chat/long-message","chat/mine-selected","chat/japanese"};
        frame(names[variant],[&] {
            capture_language=variant==3?"ja":"en";
            std::vector<display::renderer::OpenChatRoomMessage> messages;
            if(variant==3)messages={{"はづき","こんにちは 沖縄",false},{"私","CQやりませんか？",true}};
            else if(variant==1)messages={{"Hazuki","Hello world this is a long message wrapping across several lines",false}};
            else messages={{"Hazuki","Hello",false},{"Me","CQ",variant==2}};
            display::renderer::render_open_chat_room(sprite,[]{return true;},[]{},"OPEN CHAT",messages);
            capture_language="en";
        });
    }
    for(int variant=0;variant<3;variant++) {
        const char* names[]={"settings/default","settings/selected","settings/scrolled"};
        frame(names[variant],[&] {
            SettingMenuRenderRow rows[]={{"Profile",SettingStatusIndicator::None,""},{"Wi-Fi",SettingStatusIndicator::On,""},{"Sound",SettingStatusIndicator::Off,""},{"Vibration",SettingStatusIndicator::Busy,""},{"Language",SettingStatusIndicator::None,"EN"},{"Firmware",SettingStatusIndicator::None,""}};
            render_setting_menu(rows,6,variant==0?0:variant==1?2:5);
        });
    }
    for(int variant=0;variant<2;variant++) {
        frame(variant?"dialog/confirm-yes":"dialog/confirm-no",[&] {
            auto api=display::renderer::make_confirm_dialog_render_api(sprite,[]{});
            api.begin_frame(); api.draw_title("Confirm?"); api.draw_buttons(variant); api.present();
        });
    }
    for(int v=0;v<2;v++) {
        frame(v?"profile/scrolled":"profile/default",[&]{render_profile_info({{"Name","Hazuki"},{"ID","ABCD2345"},{"Version","1.0"}},v?-28:0);});
        frame(v?"tra/selected-synth":"tra/default",[&]{render_tra_launcher(v?3:0);});
        frame(v?"ehagaki/menu-timeline":"ehagaki/menu-default",[&]{render_ehagaki_menu(v?2:0);});
        frame(v?"dialog/factory-reset-yes":"dialog/factory-reset-no",[&]{render_factory_reset_confirm(v);});
        frame(v?"composer/playing":"composer/default",[&]{ std::vector<ComposerStepRender> steps(16);for(int i=0;i<16;i++){steps[i].label=i%3?'A':'-';steps[i].active=i%3==1;}render_step_composer(steps,2,v?4:-1,60,"PIANO",120,v);});
        frame(v?"rooms/selected":"rooms/default",[&]{auto api=display::renderer::make_room_selector_render_api(sprite,[]{return true;},[]{});api.begin_frame();api.draw_header("ROOMS");api.draw_row(0,"LOBBY",v==0);api.draw_row(1,"OKINAWA",v==1);api.draw_row(2,"CQ",false);api.draw_footer("Enter:Join Back:Exit");api.present();});
    }
    frame("wifi/scanning",[&]{render_center_status("Wi-Fi","Scanning...",true);});
    frame("wifi/connecting",[&]{render_center_status("Wi-Fi","Connecting...",true);});
    frame("wifi/error",[&]{render_center_status("Wi-Fi","Failed / retry",true);});
    for(int v=0;v<3;v++)frame(v==0?"wifi/list":v==1?"wifi/selected":"wifi/scrolled",[&]{render_wifi_list({"Wi-Fi","Mobus-Home","Demo","Cafe","Other"},v==0?0:v==1?2:4,"Wi-Fi",true);});
    frame("wifi/password",[&]{render_wifi_text_input("Password","secret",1,1,true);});
    frame("wifi/password-delete",[&]{render_wifi_text_input("Password","secret",13,1,true);});
    frame("text/default",[&]{render_center_status("Mo-Bus",nullptr,false);});
    frame("text/two-lines",[&]{render_center_status("Mo-Bus","Ready",false);});
    // Original drawBitmap reads 90 bytes from an 87-byte array. Do not execute
    // undefined behavior or turn arbitrary host memory into a golden baseline.
    frame("text/blank",[&]{render_blank_screen();});
    // Glyph masks are derived from the actual font rasterizer, not redrawn.
    // Both drawString and print origins are captured, including opaque pixels.
    std::ofstream f(out+"/glyphs.bin",std::ios::binary);
    const lgfx::IFont* fonts[]={&mobus_fonts::MobusCustom7(),&lgfx::fonts::Font2,&mobus_fonts::MisakiGothic8()};
    std::vector<uint32_t> cps; for(uint32_t cp=32;cp<127;cp++)cps.push_back(cp);
    for(uint32_t cp=0x30a0;cp<=0x30ff;cp++)cps.push_back(cp);
    cps.push_back(0xfffd);
    const std::string jp="はづきこんにちは 沖縄私CQやりませんか？戻る長押し送信受信ソウシン　モドル";
    for(size_t i=0;i<jp.size();) {
        uint8_t c=jp[i++]; uint32_t cp=c; int n=0;
        if(c>=0xe0){cp=c&15;n=2;}else if(c>=0xc0){cp=c&31;n=1;}
        while(n--)cp=(cp<<6)|(jp[i++]&63);
        if(std::find(cps.begin(),cps.end(),cp)==cps.end())cps.push_back(cp);
    }
    auto byte=[&](uint8_t b){f.put(static_cast<char>(b));};
    for(int font=0;font<3;font++)for(int mode=0;mode<2;mode++)for(uint32_t cp:cps) {
        char text[5]={};
        if(cp<128)text[0]=cp;
        else if(cp<2048){text[0]=0xc0|(cp>>6);text[1]=0x80|(cp&63);}
        else {text[0]=0xe0|(cp>>12);text[1]=0x80|((cp>>6)&63);text[2]=0x80|(cp&63);}
        sprite.setFont(fonts[font]);sprite.setTextColor(0xffff,0);sprite.setTextWrap(false);
        const int measured=sprite.textWidth(text);
        uint8_t ink[128]={},opaque[128]={};int advance=0;
        for(int bg=0;bg<2;bg++) {
            sprite.fillScreen(bg?0xffff:0);sprite.setCursor(8,8);
            advance=mode?(sprite.print(text),sprite.getCursorX()-8):sprite.drawString(text,8,8);
            for(int y=0;y<32;y++)for(int x=0;x<32;x++) {
                const bool on=sprite.readPixel(8+x,8+y)!=0;
                const int idx=y*4+x/8;const int bit=128>>(x%8);
                if(!bg&&on)ink[idx]|=bit;
                if((!bg&&on)||(bg&&!on))opaque[idx]|=bit;
            }
        }
        byte(font);byte(mode);for(int b=0;b<4;b++)byte(cp>>(b*8));
        byte(advance);byte(measured);byte(sprite.fontHeight());
        f.write(reinterpret_cast<char*>(ink),128);f.write(reinterpret_cast<char*>(opaque),128);
    }
}
