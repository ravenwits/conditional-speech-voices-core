// ISO 639-1 voice languages, with Project Zomboid's locale codes for its variants.
const codes =
  "aa ab ae af ak am an ar as av ay az ba be bg bh bi bm bn bo br bs ca ce ch co cr cs cu cv cy da de dv dz ee el en eo es et eu fa ff fi fj fo fr fy ga gd gl gn gu gv ha he hi ho hr ht hu hy hz ia id ie ig ii ik io is it iu ja jv ka kg ki kj kk kl km kn ko kr ks ku kv kw ky la lb lg li ln lo lt lu lv mg mh mi mk ml mn mr ms mt my na nb nd ne ng nl nn no nr nv ny oc oj om or os pa pi pl ps pt qu rm rn ro ru rw sa sc sd se sg si sk sl sm sn so sq sr ss st su sv sw ta te tg th ti tk tl tn to tr ts tt tw ty ug uk ur uz ve vi vo wa wo xh yi yo za zh zu".split(
    " ",
  );
const names = new Intl.DisplayNames(["en"], { type: "language" });
const aliases: Record<string, string> = { ja: "JP", uk: "UA", zh: "CN" };
export const languages = codes
  .filter((c) => c !== "ch")
  .map((c) => ({
    value: aliases[c] || c.toUpperCase(),
    label: `${names.of(c) || c} (${aliases[c] || c.toUpperCase()})`,
  }));
languages.push(
  { value: "CH", label: "Chinese, Traditional (CH)" },
  { value: "PTBR", label: "Portuguese, Brazil (PTBR)" },
  { value: "ES_CL", label: "Spanish, Chile (ES_CL)" },
  { value: "ES_MX", label: "Spanish, Mexico (ES_MX)" },
  { value: "CHA", label: "Chamorro (CHA)" },
);

// Voice language choices are independent of the game UI language.
const additional = `ACE|Acehnese
ACH|Acholi
ALZ|Alur
AWA|Awadhi
BAN|Balinese
BAL|Baluchi
BCI|Baoule
BTX|Batak Karo
BTS|Batak Simalungun
BBC|Batak Toba
BEM|Bemba
BEW|Betawi
BHO|Bhojpuri
BIK|Bikol
BUA|Buryat
YUE|Cantonese
CEB|Cebuano
CHK|Chuukese
CRH_CYRL|Crimean Tatar (Cyrillic)
CRH_LATN|Crimean Tatar (Latin)
PRS|Dari
DIN|Dinka
DOI|Dogri
DOV|Dombe
DYU|Dyula
FON|Fon
FR_CA|French (Canada)
FUR|Friulian
GAA|Ga
HCK|Hakha Chin
HAW|Hawaiian
HIL|Hiligaynon
HMN|Hmong
HRX|Hunsrik
IBA|Iban
ILO|Ilocano
IU_LATN|Inuktut (Latin)
IU_CANS|Inuktut (Syllabics)
JAM|Jamaican Patois
KAC|Jingpo
PAM|Kapampangan
KHA|Khasi
CGA|Kiga
KTU|Kituba
TRP|Kokborok
GOM|Konkani
KRI|Krio
CKB|Kurdish (Sorani)
LTG|Latgalian
LIJ|Ligurian
LMO|Lombard
LUA|Luba-Kasai
LUO|Luo
MAD|Madurese
MAI|Maithili
MAK|Makassar
MS_ARAB|Malay (Jawi)
MAM|Mam
MRW|Marwadi
MFE|Mauritian Creole
MHR|Meadow Mari
MNI|Meiteilon (Manipuri)
MIN|Minang
LUS|Mizo
NAH|Nahuatl (Eastern Huasteca)
NDC|Ndau
NEW|Nepalbhasa (Newari)
NKO|NKo
NUS|Nuer
PAG|Pangasinan
PAP|Papiamento
PT_PT|Portuguese (Portugal)
PA_GURU|Punjabi (Gurmukhi)
PA_ARAB|Punjabi (Shahmukhi)
KEK|Q'eqchi'
ROM|Romani
SAT_LATN|Santali (Latin)
SAT_OLCK|Santali (Ol Chiki)
NSO|Sepedi
CRS|Seychellois Creole
SHN|Shan
SCN|Sicilian
SZL|Silesian
SUS|Susu
BER|Tamazight
BER_TFNG|Tamazight (Tifinagh)
TET|Tetum
TIV|Tiv
TPI|Tok Pisin
TCY|Tulu
TUM|Tumbuka
TYV|Tuvan
UDM|Udmurt
VEC|Venetian
WAR|Waray
SAH|Yakut
YUA|Yucatec Maya
ZAP|Zapotec`;
for (const entry of additional.split("\n")) {
  const [value, name] = entry.split("|");
  if (!languages.some((l) => l.value === value))
    languages.push({ value, label: `${name} (${value})` });
}
const commonNames: Record<string, string> = {
  CN: "Chinese (Simplified)",
  CH: "Chinese (Traditional)",
  FF: "Fulani",
  NY: "Chichewa",
  TL: "Filipino",
  HT: "Haitian Creole",
  KL: "Kalaallisut",
  LG: "Luganda",
  KU: "Kurdish (Kurmanji)",
  MI: "Maori",
  MY: "Myanmar (Burmese)",
  NR: "Ndebele (South)",
  OR: "Odia (Oriya)",
  RN: "Rundi",
  SE: "Sami (North)",
  GD: "Scots Gaelic",
  ST: "Sesotho",
  SS: "Swati",
  VE: "Venda",
  PA: "Punjabi",
  PT: "Portuguese",
  IU: "Inuktut",
  KG: "Kikongo",
};
for (const item of languages)
  if (commonNames[item.value])
    item.label = `${commonNames[item.value]} (${item.value})`;
languages.sort((a, b) => a.label.localeCompare(b.label));

for (let i = languages.length - 1; i >= 0; i--) {
  const item = languages[i];
  if (item.label.split(" (")[0].toLowerCase() === item.value.toLowerCase())
    languages.splice(i, 1);
}
