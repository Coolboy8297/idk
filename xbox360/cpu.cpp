#include <cstdint>
#include <cstring>
#if defined(__EMSCRIPTEN__)
#include <emscripten/emscripten.h>
#define API EMSCRIPTEN_KEEPALIVE
#else
#define API
#endif
namespace {
constexpr uint32_t RAM_SIZE = 64 * 1024;
uint32_t gpr[32]; uint8_t ram[RAM_SIZE]; uint32_t pc=0, cr=0, steps=0, last_opcode=0;
bool halted=false; const char* status="Ready";
int32_t sign_extend(uint32_t v,unsigned bits){const uint32_t s=1u<<(bits-1);return static_cast<int32_t>((v^s)-s);}
uint32_t read32(uint32_t a){if(a>RAM_SIZE-4||(a&3u)){halted=true;status="Memory fault: unaligned or out-of-range read";return 0;}return(uint32_t(ram[a])<<24)|(uint32_t(ram[a+1])<<16)|(uint32_t(ram[a+2])<<8)|uint32_t(ram[a+3]);}
void write32(uint32_t a,uint32_t v){if(a>RAM_SIZE-4||(a&3u)){halted=true;status="Memory fault: unaligned or out-of-range write";return;}ram[a]=uint8_t(v>>24);ram[a+1]=uint8_t(v>>16);ram[a+2]=uint8_t(v>>8);ram[a+3]=uint8_t(v);}
void put_instruction(uint32_t a,uint32_t v){if(a+4>RAM_SIZE)return;ram[a]=uint8_t(v>>24);ram[a+1]=uint8_t(v>>16);ram[a+2]=uint8_t(v>>8);ram[a+3]=uint8_t(v);}
}
extern "C" {
API void cpu_reset(){std::memset(gpr,0,sizeof(gpr));std::memset(ram,0,sizeof(ram));pc=cr=steps=last_opcode=0;halted=false;status="Ready";}
API void cpu_load_demo(){cpu_reset();put_instruction(0,(14u<<26)|(3u<<21)|5u);put_instruction(4,(14u<<26)|(4u<<21)|7u);put_instruction(8,(31u<<26)|(5u<<21)|(3u<<16)|(4u<<11)|(266u<<1));put_instruction(12,(36u<<26)|(5u<<21)|0x100u);put_instruction(16,0xFFFFFFFFu);status="Demo loaded: 5 + 7, then store result at RAM[0x100]";}
API int cpu_step(){if(halted)return 0;if(pc>RAM_SIZE-4||(pc&3u)){halted=true;status="Instruction fetch fault";return 0;}uint32_t ins=read32(pc);if(halted)return 0;last_opcode=ins;if(ins==0xFFFFFFFFu){halted=true;status="Demo stop marker reached";return 0;}uint32_t op=ins>>26,rt=(ins>>21)&31u,ra=(ins>>16)&31u,rb=(ins>>11)&31u;int32_t simm=sign_extend(ins&0xFFFFu,16);uint32_t old=pc;pc+=4;
switch(op){
case 14:gpr[rt]=(ra==0?0:gpr[ra])+uint32_t(simm);break;
case 15:gpr[rt]=(ra==0?0:gpr[ra])+(uint32_t(simm)<<16);break;
case 24:gpr[ra]=gpr[rt]|(ins&0xFFFFu);break;
case 25:gpr[ra]=gpr[rt]|((ins&0xFFFFu)<<16);break;
case 28:gpr[ra]=gpr[rt]&(ins&0xFFFFu);cr=gpr[ra]==0?0x20000000u:0;break;
case 32:gpr[rt]=read32((ra==0?0:gpr[ra])+uint32_t(simm));break;
case 36:write32((ra==0?0:gpr[ra])+uint32_t(simm),gpr[rt]);break;
case 18:{int32_t d=sign_extend(ins&0x03FFFFFCu,26);pc=(ins&2u)?uint32_t(d):old+uint32_t(d);break;}
case 16:{uint32_t bo=(ins>>21)&31u,bi=(ins>>16)&31u;int32_t d=sign_extend(ins&0xFFFCu,16);bool c=((cr>>(31u-bi))&1u)!=0;bool take=((bo&0x10u)!=0)||(c==((bo&0x08u)!=0));if(take)pc=(ins&2u)?uint32_t(d):old+uint32_t(d);break;}
case 31:{uint32_t xo=(ins>>1)&0x3FFu;if(xo==266)gpr[rt]=gpr[ra]+gpr[rb];else if(xo==40)gpr[rt]=gpr[rb]-gpr[ra];else{halted=true;status="Unsupported opcode-31 XO";pc=old;return 0;}break;}
default:halted=true;status="Unsupported instruction: prototype supports a small PowerPC subset";pc=old;return 0;
}
if(!halted){++steps;status="Running";}return halted?0:1;}
API int cpu_run(uint32_t max_steps){uint32_t n=0;while(!halted&&n<max_steps){if(!cpu_step())break;++n;}if(!halted&&n==max_steps)status="Paused at instruction budget";return int(n);}
API uint32_t cpu_get_pc(){return pc;} API uint32_t cpu_get_reg(uint32_t i){return i<32?gpr[i]:0;} API uint32_t cpu_get_steps(){return steps;} API uint32_t cpu_get_last_opcode(){return last_opcode;} API uint32_t cpu_get_memory_word(uint32_t a){return read32(a);} API int cpu_is_halted(){return halted?1:0;} API const char* cpu_get_status(){return status;}
}