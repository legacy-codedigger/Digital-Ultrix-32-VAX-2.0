(File parser.l)
(twop lambda eq)
(get_while (lambda . local) cadr car frm_hnk *throw memq not eq atom find listp and cond quote parse let)
(prs_fn (lambda . local) car atom cond quote concat)
(frm_hnk lexpr *throw makhunk car return caar null quote assq cons |1-| + cdr <& arg do minusp eq cond let listify setq prog)
(get_constr (lambda . local) setq reverse cons makhunk return cadr car listp parse do null not list quote *throw twop eq cond)
(get_def (lambda . local) quote cadr concat *throw memq listp not eq atom find cond get_tkn setq prog)
(Pop (lambda . local) cadr car twop return onep eq setq prog *throw null cond)
(Push (lambda . local) *throw list onep setq bigp not cdr null and zerop eq cond)
(get_condit (lambda . local) Pop frm_hnk *throw memq not eq atom find listp and cond quote parse setq prog)
(g00767::p$while$$ lambda get_while *throw null not cond)
(g00762::p$semi$$ lambda Pop quote list)
(g00757::p$arrow$$ lambda get_condit)
(g00750::p$colon$$ lambda Pop quote list *throw cond)
(g00743::p$colon$$ lambda Pop quote list *throw cond)
(g00738::p$constant$$ lambda makhunk quote list)
(g00733::p$constant$$ lambda makhunk quote list)
(g00728::p$constant$$ lambda makhunk quote list)
(g00723::p$constant$$ lambda makhunk quote list)
(g00718::p$constant$$ lambda makhunk quote list)
(g00713::p$constant$$ lambda makhunk quote list)
(g00708::p$constant$$ lambda makhunk quote list)
(g00703::p$constant$$ lambda makhunk quote list)
(g00698::p$select$$ lambda makhunk quote list)
(g00693::p$select$$ lambda makhunk quote list)
(g00688::p$select$$ lambda makhunk quote list)
(g00683::p$select$$ lambda makhunk quote list)
(g00678::p$select$$ lambda makhunk quote list)
(g00673::p$select$$ lambda makhunk quote list)
(g00668::p$select$$ lambda makhunk quote list)
(g00663::p$select$$ lambda makhunk quote list)
(g00658::p$builtin$$ lambda cadr concat quote list)
(g00653::p$builtin$$ lambda cadr concat quote list)
(g00648::p$builtin$$ lambda cadr concat quote list)
(g00643::p$builtin$$ lambda cadr concat quote list)
(g00638::p$builtin$$ lambda cadr concat quote list)
(g00633::p$builtin$$ lambda cadr concat quote list)
(g00628::p$builtin$$ lambda cadr concat quote list)
(g00623::p$builtin$$ lambda cadr concat quote list)
(g00618::p$builtin$$ lambda cadr concat quote list)
(g00613::p$builtin$$ lambda cadr concat quote list)
(g00608::p$defined$$ lambda cadr concat quote list)
(g00603::p$defined$$ lambda cadr concat quote list)
(g00598::p$defined$$ lambda cadr concat quote list)
(g00593::p$defined$$ lambda cadr concat quote list)
(g00588::p$defined$$ lambda cadr concat quote list)
(g00583::p$defined$$ lambda cadr concat quote list)
(g00578::p$defined$$ lambda cadr concat quote list)
(g00573::p$defined$$ lambda cadr concat quote list)
(g00568::p$defined$$ lambda cadr concat quote list)
(g00563::p$defined$$ lambda cadr concat quote list)
(g00556::p$rbrack$$ lambda Pop null cond quote list)
(g00549::p$rbrack$$ lambda Pop null cond quote list)
(g00544::p$lbrack$$ lambda get_constr quote list)
(g00539::p$lbrack$$ lambda get_constr quote list)
(g00534::p$lbrack$$ lambda get_constr quote list)
(g00529::p$lbrack$$ lambda get_constr quote list)
(g00524::p$lbrack$$ lambda get_constr quote list)
(g00519::p$lbrack$$ lambda get_constr quote list)
(g00514::p$lbrack$$ lambda get_constr quote list)
(g00509::p$lbrack$$ lambda get_constr quote list)
(g00504::p$lbrack$$ lambda get_constr quote list)
(g00499::p$lbrack$$ lambda get_constr quote list)
(g00494::p$comma$$ lambda Pop quote list)
(g00489::p$comma$$ lambda Pop quote list)
(g00484::p$compos$$ lambda parse Pop frm_hnk quote list)
(g00479::p$compos$$ lambda parse Pop frm_hnk quote list)
(g00474::p$compos$$ lambda parse Pop frm_hnk quote list)
(g00469::p$compos$$ lambda parse Pop frm_hnk quote list)
(g00464::p$compos$$ lambda parse Pop frm_hnk quote list)
(g00459::p$compos$$ lambda parse Pop frm_hnk quote list)
(g00454::p$compos$$ lambda parse Pop frm_hnk quote list)
(g00447::p$ti$$ lambda parse frm_hnk quote list *throw eq twop cond)
(g00440::p$ti$$ lambda parse frm_hnk quote list *throw null not cond)
(g00433::p$ti$$ lambda parse frm_hnk quote list *throw null not cond)
(g00426::p$ti$$ lambda parse frm_hnk quote list *throw null not cond)
(g00419::p$ti$$ lambda parse frm_hnk quote list *throw null not cond)
(g00412::p$ti$$ lambda parse frm_hnk quote list *throw null not cond)
(g00405::p$ti$$ lambda parse frm_hnk quote list *throw null not cond)
(g00398::p$ti$$ lambda parse frm_hnk quote list *throw null not cond)
(g00391::p$ti$$ lambda parse frm_hnk quote list *throw null not cond)
(g00384::p$ti$$ lambda parse frm_hnk quote list *throw null not cond)
(g00377::p$insert$$ lambda parse frm_hnk quote list *throw eq twop cond)
(g00370::p$insert$$ lambda parse frm_hnk quote list *throw null not cond)
(g00363::p$insert$$ lambda parse frm_hnk quote list *throw null not cond)
(g00356::p$insert$$ lambda parse frm_hnk quote list *throw null not cond)
(g00349::p$insert$$ lambda parse frm_hnk quote list *throw null not cond)
(g00342::p$insert$$ lambda parse frm_hnk quote list *throw null not cond)
(g00335::p$insert$$ lambda parse frm_hnk quote list *throw null not cond)
(g00328::p$insert$$ lambda parse frm_hnk quote list *throw null not cond)
(g00321::p$insert$$ lambda parse frm_hnk quote list *throw null not cond)
(g00314::p$insert$$ lambda parse frm_hnk quote list *throw null not cond)
(g00307::p$alpha$$ lambda parse frm_hnk quote list *throw eq twop cond)
(g00300::p$alpha$$ lambda parse frm_hnk quote list *throw null not cond)
(g00293::p$alpha$$ lambda parse frm_hnk quote list *throw null not cond)
(g00286::p$alpha$$ lambda parse frm_hnk quote list *throw null not cond)
(g00279::p$alpha$$ lambda parse frm_hnk quote list *throw null not cond)
(g00272::p$alpha$$ lambda parse frm_hnk quote list *throw null not cond)
(g00265::p$alpha$$ lambda parse frm_hnk quote list *throw null not cond)
(g00258::p$alpha$$ lambda parse frm_hnk quote list *throw null not cond)
(g00251::p$alpha$$ lambda parse frm_hnk quote list *throw null not cond)
(g00244::p$alpha$$ lambda parse frm_hnk quote list *throw null not cond)
(g00239::p$rparen$$ lambda Pop nreverse quote list)
(g00234::p$rparen$$ lambda Pop quote list)
(g00225::p$rparen$$ lambda quote terpri patom get_cmd *throw null not cond)
(g00220::p$rparen$$ lambda Pop quote list)
(g00211::p$lparen$$ lambda parse *catch trap_err quote list *throw eq twop cond)
(g00202::p$lparen$$ lambda parse *catch trap_err quote list *throw null not cond)
(g00193::p$lparen$$ lambda parse *catch trap_err quote list *throw null not cond)
(g00184::p$lparen$$ lambda parse *catch trap_err quote list *throw null not cond)
(g00175::p$lparen$$ lambda parse *catch trap_err quote list *throw null not cond)
(g00166::p$lparen$$ lambda parse *catch trap_err quote list *throw null not cond)
(g00157::p$lparen$$ lambda parse *catch trap_err quote list *throw null not cond)
(g00148::p$lparen$$ lambda parse *catch trap_err quote list *throw null not cond)
(g00139::p$lparen$$ lambda parse *catch trap_err quote list *throw null not cond)
(g00130::p$lparen$$ lambda parse *catch trap_err quote list *throw null not cond)
(trap_err (lambda . local) *throw memq listp not eq atom find cond)
(g00097::p$rbrace$$ lambda Pop quote list eq tyo and tyi let Tyi do null progn *throw not cond)
(g00078::p$rbrace$$ lambda Pop quote list eq tyo and tyi let Tyi do null progn *throw not cond)
(g00071::p$lbrace$$ lambda get_def quote list *throw cond)
(parse lambda twop Push onep bigp zerop or cdr car return Internal-bcdcall getdisc bcdp cxr getd symbolp and funcall get setq cadr memq listp not atom find list prs_fn plist null *throw quote cond eq get_tkn do let)