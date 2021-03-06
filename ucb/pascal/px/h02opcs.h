#define O_NODUMP 0001
#define O_BEG 0002
#define O_END 0003
#define O_CALL 0004
#define O_FCALL 0005
#define O_FRTN 0006
#define O_FSAV 0007
#define O_SDUP2 0010
#define O_SDUP4 0011
#define O_TRA 0012
#define O_TRA4 0013
#define O_GOTO 0014
#define O_LINO 0015
#define O_PUSH 0016
#define O_IF 0020
#define O_REL2 0021
#define O_REL4 0022
#define O_REL24 0023
#define O_REL42 0024
#define O_REL8 0025
#define O_RELG 0026
#define O_RELT 0027
#define O_REL28 0030
#define O_REL48 0031
#define O_REL82 0032
#define O_REL84 0033
#define O_AND 0034
#define O_OR 0035
#define O_NOT 0036
#define O_AS2 0040
#define O_AS4 0041
#define O_AS24 0042
#define O_AS42 0043
#define O_AS21 0044
#define O_AS41 0045
#define O_AS28 0046
#define O_AS48 0047
#define O_AS8 0050
#define O_AS 0051
#define O_INX2P2 0052
#define O_INX4P2 0053
#define O_INX2 0054
#define O_INX4 0055
#define O_OFF 0056
#define O_NIL 0057
#define O_ADD2 0060
#define O_ADD4 0061
#define O_ADD24 0062
#define O_ADD42 0063
#define O_ADD28 0064
#define O_ADD48 0065
#define O_ADD82 0066
#define O_ADD84 0067
#define O_SUB2 0070
#define O_SUB4 0071
#define O_SUB24 0072
#define O_SUB42 0073
#define O_SUB28 0074
#define O_SUB48 0075
#define O_SUB82 0076
#define O_SUB84 0077
#define O_MUL2 0100
#define O_MUL4 0101
#define O_MUL24 0102
#define O_MUL42 0103
#define O_MUL28 0104
#define O_MUL48 0105
#define O_MUL82 0106
#define O_MUL84 0107
#define O_ABS2 0110
#define O_ABS4 0111
#define O_ABS8 0112
#define O_NEG2 0114
#define O_NEG4 0115
#define O_NEG8 0116
#define O_DIV2 0120
#define O_DIV4 0121
#define O_DIV24 0122
#define O_DIV42 0123
#define O_MOD2 0124
#define O_MOD4 0125
#define O_MOD24 0126
#define O_MOD42 0127
#define O_ADD8 0130
#define O_SUB8 0131
#define O_MUL8 0132
#define O_DVD8 0133
#define O_STOI 0134
#define O_STOD 0135
#define O_ITOD 0136
#define O_ITOS 0137
#define O_DVD2 0140
#define O_DVD4 0141
#define O_DVD24 0142
#define O_DVD42 0143
#define O_DVD28 0144
#define O_DVD48 0145
#define O_DVD82 0146
#define O_DVD84 0147
#define O_RV1 0150
#define O_RV14 0151
#define O_RV2 0152
#define O_RV24 0153
#define O_RV4 0154
#define O_RV8 0155
#define O_RV 0156
#define O_LV 0157
#define O_LRV1 0160
#define O_LRV14 0161
#define O_LRV2 0162
#define O_LRV24 0163
#define O_LRV4 0164
#define O_LRV8 0165
#define O_LRV 0166
#define O_LLV 0167
#define O_IND1 0170
#define O_IND14 0171
#define O_IND2 0172
#define O_IND24 0173
#define O_IND4 0174
#define O_IND8 0175
#define O_IND 0176
#define O_CON1 0200
#define O_CON14 0201
#define O_CON2 0202
#define O_CON24 0203
#define O_CON4 0204
#define O_CON8 0205
#define O_CON 0206
#define O_LVCON 0207
#define O_RANG2 0210
#define O_RANG42 0211
#define O_RSNG2 0212
#define O_RSNG42 0213
#define O_RANG4 0214
#define O_RANG24 0215
#define O_RSNG4 0216
#define O_RSNG24 0217
#define O_STLIM 0220
#define O_LLIMIT 0221
#define O_BUFF 0222
#define O_HALT 0223
#define O_ORD2 0230
#define O_CONG 0231
#define O_CONC 0232
#define O_CONC4 0233
#define O_ABORT 0234
#define O_BPT 0235
#define O_PXPBUF 0236
#define O_COUNT 0237
#define O_CASE1OP 0240
#define O_CASE2OP 0241
#define O_CASE4OP 0242
#define O_CASEBEG 0243
#define O_CASE1 0244
#define O_CASE2 0245
#define O_CASE4 0246
#define O_CASEEND 0247
#define O_ADDT 0250
#define O_SUBT 0251
#define O_MULT 0252
#define O_INCT 0253
#define O_CTTOT 0254
#define O_CARD 0255
#define O_IN 0256
#define O_ASRT 0257
#define O_FOR1U 0260
#define O_FOR2U 0261
#define O_FOR4U 0262
#define O_FOR1D 0263
#define O_FOR2D 0264
#define O_FOR4D 0265
#define O_READE 0270
#define O_READ4 0271
#define O_READC 0272
#define O_READ8 0273
#define O_READLN 0274
#define O_EOF 0275
#define O_EOLN 0276
#define O_WRITEC 0300
#define O_WRITES 0301
#define O_WRITEF 0302
#define O_WRITLN 0303
#define O_PAGE 0304
#define O_NAM 0305
#define O_MAX 0306
#define O_MIN 0307
#define O_UNIT 0310
#define O_UNITINP 0311
#define O_UNITOUT 0312
#define O_MESSAGE 0313
#define O_GET 0314
#define O_PUT 0315
#define O_FNIL 0316
#define O_DEFNAME 0320
#define O_RESET 0321
#define O_REWRITE 0322
#define O_FILE 0323
#define O_REMOVE 0324
#define O_FLUSH 0325
#define O_PACK 0330
#define O_UNPACK 0331
#define O_NEW 0332
#define O_DISPOSE 0333
#define O_DFDISP 0334
#define O_ARGC 0335
#define O_ARGV 0336
#define O_CLCK 0340
#define O_WCLCK 0341
#define O_SCLCK 0342
#define O_DATE 0343
#define O_TIME 0344
#define O_UNDEF 0345
#define O_ATAN 0350
#define O_COS 0351
#define O_EXP 0352
#define O_LN 0353
#define O_SIN 0354
#define O_SQRT 0355
#define O_CHR2 0356
#define O_CHR4 0357
#define O_ODD2 0360
#define O_ODD4 0361
#define O_PRED2 0362
#define O_PRED4 0363
#define O_PRED24 0364
#define O_SUCC2 0365
#define O_SUCC4 0366
#define O_SUCC24 0367
#define O_SEED 0370
#define O_RANDOM 0371
#define O_EXPO 0372
#define O_SQR2 0373
#define O_SQR4 0374
#define O_SQR8 0375
#define O_ROUND 0376
#define O_TRUNC 0377
