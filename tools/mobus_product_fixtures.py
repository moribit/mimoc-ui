"""Fixed final render arguments, shared by the independent C++ oracle and Zig.
No screen class, transport, NVS, audio, or application runtime is executed.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEFAULTS=dict(kind="status",screen="cq",title="",subtitle="",message="",morse="",alphabet="",remote="",status="",notice="",locale="en",cursor=False,overlay=False,persistent=False,invert=False,two_lines=False,selected=0,offset=0,x_offset=0,lang=0,
 masks=[0]*6,accents=[0]*6,track=0,step=0,playhead=-1,playing=False,note=-1,tempo=120,enabled=63,header=-1,dialog=0,slot=1,yes=False,page=0,pages=4,preset=0,page_item=0,sound_track=3,sound_field=0,
 entries=[],front=True,image=False,bitmap_text=False,scroll=0,page_overlay=False,flip=0,reveal=-1,count=5,limit=30,ascii_header=False,
 cx=40,cy=25,anchor=False,ax=18,ay=12,mode=0,menu=False,menu_selected=0,white=True,stroke=1,active_mode=0,menu_focus=1,left_selected=0,undo=False,redo=False,stroke_menu=False,filled=False,stage=0,option=False,clear=False,width=16,height=12)
SCENARIOS=[]
def add(name,**kw):
 f=DEFAULTS|kw;f['name']=name;SCENARIOS.append(f)
def ent(sender,text):return dict(sender=sender,text=text)
add('qsp/empty-loading',kind='qsp',screen='qsp')
add('qsp/single-incoming',kind='qsp',screen='qsp',entries=[ent('Hazuki','Hello')])
add('qsp/single-outgoing',kind='qsp',screen='qsp',entries=[ent('Me','CQ')])
mixed=[ent('Hazuki','Hello'),ent('Me','CQ'),ent('Hazuki','OK'),ent('Hazuki','See you')]
for name,entries,offset in [('mixed',mixed,0),('sender-change',mixed[:3],0),('long-wrap',[ent('Hazuki','Hello world this is a long message wrapping across several lines')],0),('scrolled-middle',mixed,-13),('scrolled-bottom',mixed,-14),('japanese',[ent('Hazuki','こんにちは 沖縄')],0),('mixed-japanese-english',[ent('Hazuki','Hello 沖縄 CQ'),ent('Me','CQやりませんか？')],0)]:add('qsp/'+name,kind='qsp',screen='qsp',entries=entries,offset=offset)
add('qsp/transient-notice',kind='qsp',screen='qsp',entries=mixed,notice='NEW MESSAGES')
for name,kw in [('empty',{}),('text',dict(message='Hello')),('morse',dict(morse='.- -...')),('decoded-preview',dict(message='CQ',alphabet='A')),('long-wrap',dict(message='Hello world this is a long message wrapping across several lines')),('japanese',dict(message='こんにちは カタカナ',locale='ja',lang=1)),('language-overlay',dict(overlay=True,lang=1)),('send-failed',dict(status='Send failed',persistent=True)),('limit-feedback',dict(message='Message limit',invert=True,x_offset=-2))]:add('qsp-compose/'+name,kind='talk',screen='qsp_compose',cursor=True,**kw)
add('cq/checking',title='Checking CQ')
add('cq/calling',kind='scan',title='Hazuki',selected=0)
for n,i in [('incoming-no-selected',0),('incoming-yes-selected',1)]:add('cq/'+n,kind='scan',title='Hazuki',selected=i,mode=1)
for n,kw in [('active-empty',{}),('active-local-text',dict(message='Hello CQ')),('active-remote-text',dict(remote='Hello Hazuki')),('active-morse',dict(message='CQ',morse='.-',remote='-.-.')),('language-overlay',dict(overlay=True,lang=1)),('active-japanese',dict(message='カタカナ こんにちは',remote='ソウシン',locale='ja',lang=1)),('active-status',dict(status='Connection weak'))]:add('cq/'+n,kind='realtime',cursor=True,**kw)
for n,t in [('ending','CQ Ended'),('error-offline','OFFLINE'),('error-failed','CQ failed')]:add('cq/'+n,title=t,subtitle='Hazuki')
pattern=[0x1111,0x1010,0x5555,0x0401,0x0080,0x0004]
for n,kw in [('grid-default',{}),('grid-pattern',dict(masks=pattern)),('grid-selected-step',dict(masks=pattern,track=3,step=7)),('grid-selected-track',dict(step=-1,track=4)),('grid-accent',dict(masks=pattern,accents=[0x0001]*6)),('grid-disabled-track',dict(enabled=55)),('grid-playing',dict(masks=pattern,playing=True,note=60)),('grid-playhead',dict(masks=pattern,playing=True,playhead=5))]:add('synth/'+n,kind='synth',screen='synth',**kw)
for i,n in enumerate(['bpm','page','sound','load','save']):add('synth/header-'+n,kind='synth',screen='synth',header=i)
add('synth/bpm-editor',kind='synth',screen='synth',dialog=7,header=0,tempo=144)
for i,n in enumerate(['length','copy','paste','clear']):add('synth/page-editor-'+n,kind='synth',screen='synth',dialog=5,page_item=i,header=1)
for i,n in enumerate(['track','preset']):add('synth/sound-editor-'+n,kind='synth',screen='synth',dialog=8,sound_field=i,header=2)
for n,d in [('load-slot',1),('save-slot',2),('load-confirm-no',3),('load-confirm-yes',3),('save-confirm-no',4),('save-confirm-yes',4),('clear-confirm',6)]:add('synth/'+n,kind='synth',screen='synth',dialog=d,yes=n.endswith('yes'),header=3 if d in [1,3] else 4)
for n,t,sub in [('preparing','Preparing',''),('browse-loading','Ehagaki','Loading...'),('browse-error','Load failed',''),('posting','Posting...',''),('complete','Posted',''),('error','Post failed','Failed')]:add('ehagaki/'+n,screen='ehagaki_edit',title=t,subtitle=sub,two_lines=n=='preparing')
for n,i in [('root-post-selected',0),('root-browse-selected',2)]:add('ehagaki/'+n,kind='root',screen='ehagaki_edit',selected=i)
body='Hello 沖縄 CQ\nこんにちは カタカナ\nThis is a long postcard with several wrapped lines for scrolling.\nSee you on Mo-Bus!'
for n,kw in [('browse-front-image',dict(image=True)),('browse-front-text',dict(bitmap_text=True)),('browse-back',dict(front=False)),('browse-page-overlay',dict(image=True,page_overlay=True)),('browse-text-scroll-top',dict(front=False)),('browse-text-scroll-middle',dict(front=False,scroll=2)),('browse-text-scroll-bottom',dict(front=False,scroll=99)),('browse-mine',dict(image=True)),('browse-public',dict(image=True)),('browse-flip',dict(image=True,flip=20)),('browse-text-reveal',dict(front=False,reveal=120000))]:add('ehagaki/'+n,kind='browse',screen='ehagaki_browse',title='沖縄から Hello',message=body,**kw)
for n,kw in [('title-en',dict(title='Title',limit=30)),('title-ja',dict(title='タイトル',limit=30,locale='ja',message='こんにちは カタカナ',lang=1)),('body-en',dict(title='Body',limit=200)),('body-ja',dict(title='ホンブン',limit=200,locale='ja',message='こんにちは カタカナ',lang=1)),('text-language-overlay',dict(title='Title',overlay=True,lang=1)),('text-long-wrap',dict(title='Body',message=body,limit=200)),('canvas-text',dict(title='TEXT',ascii_header=True,locale='ja',message='モバス',lang=1))]:add('ehagaki/'+n,kind='eha_text',screen='ehagaki_edit',cursor=True,**({'message':'Hello'}|kw))
for n,sel in [('visibility-private',0),('visibility-public',1)]:add('ehagaki/'+n,kind='visibility',screen='ehagaki_edit',selected=sel)
add('ehagaki/post-confirm',kind='post_confirm',screen='ehagaki_edit')
canvas=[('empty',{}),('drawing',dict(image=True)),('dot',dict(image=True,cx=30,cy=20)),('line-anchor',dict(anchor=True,mode=1,cx=18,cy=12)),('line-preview',dict(anchor=True,mode=1)),('rect-anchor',dict(anchor=True,mode=2,cx=18,cy=12)),('rect-preview',dict(anchor=True,mode=2)),('rect-fill',dict(image=True,filled=True,mode=3)),('cursor',dict(image=True,cx=50,cy=25)),('menu-right',dict(menu=True,menu_selected=1,active_mode=1)),('menu-left',dict(menu=True,menu_focus=0,left_selected=3)),('undo-enabled',dict(menu=True,menu_focus=0,undo=True)),('redo-enabled',dict(menu=True,menu_focus=0,left_selected=1,redo=True)),('stroke-menu',dict(menu=True,stroke_menu=True,stroke=2)),('rect-outline',dict(menu=True,stroke_menu=True,menu_selected=2,active_mode=2)),('rect-filled',dict(menu=True,stroke_menu=True,menu_selected=2,active_mode=2,filled=True)),('white-ink',dict(menu=True,menu_selected=4)),('black-ink',dict(menu=True,menu_selected=4,white=False)),('select-start',dict(stage=1)),('select-end',dict(stage=2,anchor=True,mode=2)),('select-mode-move',dict(stage=3,menu=True)),('select-mode-copy',dict(stage=3,menu=True,option=True)),('select-place',dict(stage=4,image=True)),('text-font-small',dict(stage=5,menu=True)),('text-font-normal',dict(stage=5,menu=True,option=True)),('text-place',dict(stage=6,image=True)),('clear-no',dict(clear=True)),('clear-yes',dict(clear=True,yes=True)),('notice',dict(notice='UNDO'))]
for n,kw in canvas:add('ehagaki/canvas-'+n,kind='canvas',screen='ehagaki_canvas',**kw)

# Supporting product surfaces: final renderer args, not screen/service execution.
for n,t,sub in [('authenticating','Factory Setup','Logging in...'),('saving','Factory Setup','Please wait'),('failed','Auth Failed','Press Select'),('complete','Setup Done','')]:add('factory/'+n,screen='factory',title=t,subtitle=sub)
for n,title,message in [('login-id','Login ID','mimoc'),('password','Password','secret'),('nickname','Nickname','Hazuki')]:add('factory/'+n,kind='keyboard',screen='factory',title=title,message=message)
for i,n in enumerate(['en','ja']):add('factory/language-'+n,kind='language',screen='factory',selected=i)
for n,time in [('hello-start',0),('hello-settled',50000000)]:add('factory/'+n,kind='hello',screen='factory',reveal=time)
for i,n in enumerate(['default','scrolled']):add('firmware/'+n,kind='list',screen='firmware',selected=i*4,entries=[ent('',t) for t in ['Ver: 1.0','Run: ota_0 @010000','Boot:ota_0 @010000','MF: stable default','Check: 12:34:56']])
for i,n in enumerate(['default','scrolled']):add('profile/product-'+n,kind='profile',screen='profile_product',offset=-i*20,entries=[ent('Name','Hazuki'),ent('Friend ID','ABCD2345'),ent('Short ID','1234')])
for n,kw in [('empty',{}),('drawing',dict(image=True)),('line-preview',dict(image=True,anchor=True,mode=1)),('rect-preview',dict(image=True,anchor=True,mode=2)),('cursor',dict(image=True))]:add('draw/'+n,kind='draw',screen='draw',**kw)
add('realtime/scanning',kind='scan_list',screen='realtime')
add('realtime/peers',kind='scan_list',screen='realtime',entries=[ent('','Hazuki'),ent('','Taro Busy')])
add('realtime/incoming',kind='scan',screen='realtime',mode=1,title='Hazuki',selected=1)
add('realtime/connecting',kind='scan',screen='realtime',title='Hazuki')
add('realtime/active',kind='realtime',screen='realtime',message='CQ',remote='Hello',cursor=True)
for n,kw in [('empty',{}),('text',dict(message='Hello')),('morse',dict(morse='._',alphabet='A')),('japanese',dict(message='カタカナ',locale='ja',lang=1))]:add('open-compose/'+n,kind='open_compose',screen='open_compose',title='OPEN CHAT',status='Enter:Send',**kw)
for f in SCENARIOS:
 if f['kind']=='eha_text':f['count']=len(f['message'])

add('qsp/sending',screen='qsp',title='Sending...')

def literal(v):
 if isinstance(v,bool):return str(v).lower()
 if isinstance(v,str):return json.dumps(v,ensure_ascii=False)
 if isinstance(v,list):
  if v and isinstance(v[0],dict):return '&.{'+','.join('.{.sender='+literal(e['sender'])+',.text='+literal(e['text'])+'}' for e in v)+'}'
  return '.{'+','.join(map(str,v))+'}' if v else '&.{}'
 return str(v)

def write_zig(path):
 types={'kind':'[]const u8','screen':'[]const u8','name':'[]const u8','entries':'[]const Entry','masks':'[6]u16','accents':'[6]u16','reveal':'i64'}
 text='// Generated reproducibly by tools/mobus_product_fixtures.py. Fixed render arguments only.\npub const Entry=struct{sender:[]const u8,text:[]const u8};\npub const Fixture=struct{\n'
 for k,v in DEFAULTS.items():
  t=types.get(k,'bool' if isinstance(v,bool) else '[]const u8' if isinstance(v,str) else 'i16')
  text+=f'{k}:{t}={literal(v)},\n'
 text+='name:[]const u8="",\n};\npub const all=[_]Fixture{\n'
 for f in SCENARIOS:text+='.{'+','.join('.'+k+'='+literal(v) for k,v in f.items() if k=='name' or v!=DEFAULTS.get(k))+'},\n'
 Path(path).write_text(text+'};\n')
 catalog='// Generated by tools/mobus_product_fixtures.py.\nconst Scenario=@import("catalog.zig").Scenario;\npub const scenarios=[_]Scenario{\n'
 for i,f in enumerate(SCENARIOS):catalog+='.{.name='+literal(f['name'])+',.screen=.'+f['screen']+',.variant='+str(i)+',.expected=@embedFile("golden/'+f['name'].replace('/','-')+'.raw")},\n'
 (Path(path).parent/'product_catalog.zig').write_text(catalog+'};\n')
if __name__=='__main__':write_zig(ROOT/'examples/mobus/reference/product_fixtures.zig')

def cpp_capture():
 lines=[]
 q=lambda v:json.dumps(v,ensure_ascii=False)
 val=lambda v:str(v).lower() if isinstance(v,bool) else str(v)
 for f in SCENARIOS:
  def args(*keys):return ','.join(q(f[k]) if isinstance(f[k],str) else val(f[k]) for k in keys)
  k=f['kind']; stmt=''
  if k=='status':stmt='render_center_status('+q(f['title'])+','+(q(f['subtitle']) if f['subtitle'] or f['two_lines'] else 'nullptr')+',false);'
  elif k=='qsp':
   stmt='ui::messagebox::ViewState v; v.my_name="Me"; v.header_text="Hazuki"; v.row_height=13; v.offset_y='+str(f['offset'])+';'
   for e in f['entries']:stmt+=' {ui::messagebox::ViewEntry e; e.from=mobus::memory::make_psram_string('+q(e['sender'])+'); e.message=mobus::memory::make_psram_string('+q(e['text'])+'); for(const auto& line:wrap_chat_history_lines(mobus::memory::to_std_string(e.message),107))e.wrapped_lines.push_back(mobus::memory::make_psram_string(line));e.line_count=e.wrapped_lines.size();v.message_views.push_back(e);}'
   stmt+='render_message_box(v,'+q(f['notice'])+');'
  elif k in ['talk','realtime','eha_text']:
   stmt='ui::talk::InputViewState v; v.message_text='+q(f['message'])+'; v.morse_text='+q(f['morse'])+'; v.alphabet_text='+q(f['alphabet'])+'; v.input_lang='+str(f['lang'])+';'
   until='1000000' if f['overlay'] else '0'
   if k=='talk':stmt+='render_talk_input(v,'+args('cursor','status','persistent')+','+until+',500000,'+args('invert','x_offset')+');'
   elif k=='realtime':stmt+='render_realtime_talk(v,'+args('cursor','remote','status')+','+until+',500000);'
   else:stmt+='render_ehagaki_text_input(v,'+args('cursor','title','count','limit')+','+until+',500000,'+val(f['ascii_header'])+');'
  elif k=='scan':stmt='render_realtime_scan({},'+args('selected')+',"",'+q(f['title'])+',RealtimeScanMode::'+('Incoming' if f['mode']==1 else 'Connecting')+');'
  elif k=='keyboard':stmt='render_wifi_text_input('+args('title','message')+',1,1,false);'
  elif k=='language':stmt='ui::language::ViewState v; ui::language::set_standard_options(v);v.selected='+args('selected')+';ui::language::refresh_title(v);ui::language::Renderer().render(v,display::renderer::make_language_dialog_render_api(sprite,ui::current_lang(),[]{}));'
  elif k=='hello':stmt='render_setup_morse_hello(0,'+args('reveal')+',180000);'
  elif k=='list':stmt='render_wifi_list({'+','.join(q(e['text']) for e in f['entries'])+'},'+args('selected')+',"Mo-Bus Info",true);'
  elif k=='profile':stmt='render_profile_info({'+','.join('{'+q(e['sender'])+','+q(e['text'])+'}' for e in f['entries'])+'},'+args('offset')+');'
  elif k=='open_compose':stmt='ui::openchat::ComposerViewState v;v.header='+args('title')+';v.message_text='+args('message')+';v.morse_text='+args('morse')+';v.preview='+args('alphabet')+';v.footer='+args('status')+';render_open_chat_composer(v);'
  elif k=='scan_list':stmt='render_realtime_scan({'+','.join('{'+q(e['text'].replace(' Busy',''))+','+val(e['text'].endswith(' Busy'))+'}' for e in f['entries'])+'},0,"","",RealtimeScanMode::Scan);'
  elif k=='synth':
   stmt='uint16_t masks[6]={'+','.join(map(str,f['masks']))+'}, accents[6]={'+','.join(map(str,f['accents']))+'}; render_synth_sequencer(masks,accents,'+args('track','step','playhead','playing','note','tempo','enabled','header','dialog','slot','yes','page','pages','preset','page_item','sound_track','sound_field')+');'
  elif k=='root':stmt='render_ehagaki_menu('+args('selected')+');'
  elif k=='visibility':stmt='render_ehagaki_public_confirm('+args('selected')+');'
  elif k=='post_confirm':stmt='render_ehagaki_post_confirm();'
  elif k in ['canvas','browse','draw']:
   stmt='uint8_t bitmap[885]={};'
   if f['image']:stmt+='for(int y=10;y<38;y++)for(int x=12;x<90;x++)if((x+y)%7==0 || (y>=20&&y<28&&x>=30&&x<60)){int bit=y*122+x; bitmap[bit/8]|=0x80>>(bit%8);}'
   if f['bitmap_text']:stmt+="for(int y=0;y<7;y++)for(int x=0;x<5;x++)if(mobus::runtime::ehagaki::glyph_pixel(*mobus::runtime::ehagaki::glyph('A'),mobus::runtime::ehagaki::CanvasFont::Normal5x7,x,y)){int bit=(20+y)*122+30+x;bitmap[bit/8]|=0x80>>(bit%8);}"
   if k=='draw':stmt+='uint8_t rows[1024]={};for(int y=0;y<58;y++)for(int x=0;x<122;x++){int bit=y*122+x;if(bitmap[bit/8]&(0x80>>(bit%8)))rows[(y+3)*16+(x+3)/8]|=1<<((x+3)%8);}render_draw_canvas(rows,sizeof(rows),'+args('cx','cy','anchor','ax','ay')+',"",0,500000,'+args('mode')+',false,0,true,1);'
   elif k=='browse':stmt+='render_ehagaki_viewer(bitmap,sizeof(bitmap),'+args('title','message')+',2,5,'+args('front','scroll','flip','page_overlay','notice','reveal')+');'
   else:
    stmt+='mobus::runtime::ehagaki::CanvasOverlay o; o.stage=static_cast<mobus::runtime::ehagaki::CanvasStage>('+str(f['stage'])+'); o.option='+val(f['option'])+';o.confirm_clear='+val(f['clear'])+';o.confirm_yes='+val(f['yes'])+';o.width='+str(f['width'])+';o.height='+str(f['height'])+';'
    stmt+='render_ehagaki_canvas(bitmap,sizeof(bitmap),'+args('cx','cy','anchor','ax','ay','notice')+','+('1000000' if f['notice'] else '0')+',500000,'+args('mode','menu','menu_selected','white','stroke','active_mode','menu_focus','left_selected','undo','redo','stroke_menu','filled')+',&o);'
  else:raise ValueError(k)
  lines.append('frame('+q(f['name'])+', [&]{capture_language='+q(f['locale'])+';'+stmt+'capture_language="en";});')
 return '\n'.join(lines)
