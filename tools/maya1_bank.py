#!/usr/bin/env python3
# Maya1 voice-DESIGN batch: generate one reference clip per Raven Hollow NPC.
# Output -> C:/Users/vstef/tts/voices/<name>.wav (Chatterbox clones these).
import os, time, torch, soundfile as sf
from transformers import AutoModelForCausalLM, AutoTokenizer
from snac import SNAC

CODE_START = 128257; CODE_END = 128258; OFF = 128266; SMIN = 128266; SMAX = 156937
SOH = 128259; EOH = 128260; SOA = 128261; EOT = 128009
OUT = r"C:\Users\vstef\tts\voices"
os.makedirs(OUT, exist_ok=True)

# name -> (voice description, a characteristic sample line ~10-15s)
CAST = {
    "marta":     ("Middle-aged woman with a warm but worn, motherly voice and a faint smoky rasp. Medium pitch, steady conversational pacing.",
                  "Welcome to the Sleeping Rook, love. Sit yourself down. The water's gone to copper again, but the ale's still honest."),
    "goran":     ("Gruff man in his forties, deep chest voice, gravelly and terse, an american accent.",
                  "You want steel, you bring me iron. The anvil keeps no secrets, and neither do I."),
    "vasile":    ("Elderly man in his sixties with a British accent, low, gravelly and weary, slow deliberate pacing.",
                  "You don't read what the ground writes. That is how it gets in. Bury it deep, and do not listen."),
    "ansel":     ("Weathered farmer in his fifties, plain-spoken and tired but kind, a rural accent, medium low pitch.",
                  "Something's been tearing up the north field by night. Boars, maybe. Maybe worse. I just want it stopped."),
    "petra":     ("Old woman in her seventies with a thin, reedy, knowing voice, a little suspicious, higher pitch and careful pacing.",
                  "The rooks won't land in the east woods. Circling, circling. Old Petra knows what that means, even if you don't."),
    "gatewarden":("Stern soldier in his forties with a firm, authoritative voice and a clipped military cadence, medium low pitch.",
                  "The Emberfall Road is closed after dark. Wolves, and worse things that walk. Turn back, or keep your blade drawn."),
    "mira":      ("Young woman in her early twenties, soft, distant and unsettling, breathy and slow, as if listening to something far away.",
                  "Do you hear it? Under the wind. It is patient. It has been waiting a very long time for someone to listen."),
    "narrator":  ("A calm, measured storyteller with a faintly ominous tone, medium pitch, neutral accent.",
                  "In the long vigil, the border villages learned to keep their lamps lit, and their questions few."),
    "default":   ("An ordinary villager, plain neutral voice, medium pitch, natural everyday pacing.",
                  "Cold night coming. Best get indoors before the lamps are lit. Mind how you go, stranger."),
}

print("loading Maya1...")
t0 = time.time()
model = AutoModelForCausalLM.from_pretrained("maya-research/maya1", torch_dtype=torch.bfloat16,
                                             device_map="cuda", trust_remote_code=True)
tok = AutoTokenizer.from_pretrained("maya-research/maya1", trust_remote_code=True)
snac = SNAC.from_pretrained("hubertsiuzdak/snac_24khz").eval().to("cuda")
print("loaded in %.0fs" % (time.time() - t0))


def build_prompt(desc, text):
    s = lambda i: tok.decode([i])
    return s(SOH) + tok.bos_token + f'<description="{desc}"> {text}' + s(EOT) + s(EOH) + s(SOA) + s(CODE_START)


def gen(desc, text):
    inp = {k: v.to("cuda") for k, v in tok(build_prompt(desc, text), return_tensors="pt").items()}
    with torch.inference_mode():
        out = model.generate(**inp, max_new_tokens=2048, min_new_tokens=28, temperature=0.4,
                             top_p=0.9, repetition_penalty=1.1, do_sample=True,
                             eos_token_id=CODE_END, pad_token_id=tok.pad_token_id)
    g = out[0, inp["input_ids"].shape[1]:].tolist()
    end = g.index(CODE_END) if CODE_END in g else len(g)
    st = [t for t in g[:end] if SMIN <= t <= SMAX]
    frames = len(st) // 7
    l1, l2, l3 = [], [], []
    for i in range(frames):
        s7 = st[i*7:(i+1)*7]
        l1.append((s7[0]-OFF) % 4096)
        l2 += [(s7[1]-OFF) % 4096, (s7[4]-OFF) % 4096]
        l3 += [(s7[2]-OFF) % 4096, (s7[3]-OFF) % 4096, (s7[5]-OFF) % 4096, (s7[6]-OFF) % 4096]
    codes = [torch.tensor(l, dtype=torch.long, device="cuda").unsqueeze(0) for l in (l1, l2, l3)]
    with torch.inference_mode():
        audio = snac.decoder(snac.quantizer.from_codes(codes))[0, 0].cpu().float().numpy()
    return audio[2048:] if len(audio) > 2048 else audio


for name, (desc, text) in CAST.items():
    t0 = time.time()
    audio = gen(desc, text)
    p = os.path.join(OUT, name + ".wav")
    sf.write(p, audio, 24000)
    print("  %-10s %.1fs  %.1fs audio  -> %s" % (name, time.time()-t0, len(audio)/24000, p))
print("BANK_DONE")
