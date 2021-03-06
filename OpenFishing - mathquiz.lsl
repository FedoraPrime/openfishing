string OFID = "openfishing";
key g_kFisher;

integer g_iChannel;
integer g_iListenH;

integer g_iTimerMode = 0;
integer TIMER_MODE_PREP_QUESTION = 0;
integer TIMER_MODE_QUESTION = 1;
integer TIMER_MODE_ANSWER = 2;
float   MIN_QUESTION_TIME = 300.0; // 5 minutes
float   MAX_QUESTION_TIME = 600.0; // 10 minutes
integer ANSWER_TIME = 15;
integer g_iAnswer;
integer NOTICE_OWNER = TRUE;
integer NOTICE_SITTER = TRUE;

integer g_iPaused = FALSE;
integer g_iSuspend = FALSE;

integer GenerateNegChannel()
{
     integer iChannel = -(1+(integer)llFrand(2147483647));
     return iChannel;
}

Debug(string sMsg)
{
    //llInstantMessage(g_kFisher, "math debug: "+sMsg);
}

default
{
    state_entry()
    {
    }
    
    changed(integer what)
    {
        if (what & CHANGED_LINK) {
            key kAvi = llAvatarOnSitTarget();
            if (kAvi==NULL_KEY) {
                llSetTimerEvent(0);
                g_kFisher = NULL_KEY;
                llListenRemove(g_iListenH);
            } else {
                g_kFisher = kAvi;
                g_iTimerMode=TIMER_MODE_PREP_QUESTION;
                float f = MIN_QUESTION_TIME+llFrand(MAX_QUESTION_TIME-MIN_QUESTION_TIME);
                llSetTimerEvent(f);                
            }
            g_iPaused = FALSE;
        }
    }
    
    link_message(integer iSender, integer iNum, string sText, key kID)
    {
        list l = llParseString2List(sText, ["|", "="], []);
        
        if (llList2String(l, 0)!=OFID) return;
        
        string sCmd = llList2String(l, 1);
        if (sCmd=="paused") {
            g_iPaused = TRUE;
        } else if (sCmd=="unpaused") {
            g_iPaused = FALSE;
        } else if (sCmd=="suspended") {
            g_iSuspend = TRUE;
            g_iTimerMode = TIMER_MODE_QUESTION;
            llSetTimerEvent(1);
        } else if (sCmd=="resumed") {
            g_iSuspend = FALSE;
        }
    }
    
    timer()
    {    
        if (g_iTimerMode==TIMER_MODE_PREP_QUESTION) {
            llSetTimerEvent(0);
            if (g_iPaused) return;

            // Request main script to suspend
            // We will receive a 'suspended' linked message when ready
            llMessageLinked(LINK_SET, 0, OFID+"|req_suspend", NULL_KEY);
        } else if (g_iTimerMode==TIMER_MODE_QUESTION) {
            llSetTimerEvent(0);            
            if (g_iPaused) return;
            if (g_iSuspend==FALSE) return;
            // Ok chair is not paused, main script suspend so we can
            // set up a math question

            // Generate math question and answer
            integer x = (integer)llFrand(16+1);
            integer y = (integer)llFrand(16+1);
            g_iAnswer = x + y;
            string sQuestion = (string)x+" + "+(string)y;
        
            // Generate button list for dialog
            integer i;
            integer iAnswerButton = (integer)llFrand(6);
            list lButtons;
            for (i = 0; i < 6; i++) {
                if (i == iAnswerButton) {
                    lButtons += [(string)g_iAnswer];
                } else {
                    integer iRandom = (integer)llFrand(32+1);
                    lButtons += [(string)iRandom];
                }
            }
            
            g_iChannel = GenerateNegChannel();
            g_iListenH = llListen(g_iChannel, "", NULL_KEY, "");
            llDialog(g_kFisher, "\nO P E N  F I S H I N G\n\nPlease answer the following math question:\n\n"+
                sQuestion, lButtons, g_iChannel);
                
            g_iTimerMode=TIMER_MODE_ANSWER;
            llSetTimerEvent(ANSWER_TIME);            
        } else if (g_iTimerMode==TIMER_MODE_ANSWER) {
            llSetTimerEvent(0);
            llListenRemove(g_iListenH);
            if (NOTICE_SITTER) llInstantMessage(g_kFisher, "You failed to answer the mathquiz in time.");
            if (NOTICE_OWNER) llOwnerSay(llKey2Name(g_kFisher)+" failed to answer the mathquiz in time.");        
            llMessageLinked(LINK_SET, 0, OFID+"|end_suspend", NULL_KEY);
            llMessageLinked(LINK_SET, 0, OFID+"|unsit", NULL_KEY);
            g_iTimerMode=TIMER_MODE_PREP_QUESTION;
        }
    }
    
    listen(integer iChannel, string sName, key kID, string sMessage)
    {
        llListenRemove(g_iListenH);
        llSetTimerEvent(0);
        
        llMessageLinked(LINK_SET, 0, OFID+"|end_suspend", NULL_KEY);
        
        if ((integer)sMessage==g_iAnswer) {
            if (NOTICE_SITTER) llInstantMessage(g_kFisher, "Correct.");
                
            g_iTimerMode=TIMER_MODE_PREP_QUESTION;
            float f = MIN_QUESTION_TIME+llFrand(MAX_QUESTION_TIME-MIN_QUESTION_TIME);
            llSetTimerEvent(f);
        } else {
            if (NOTICE_SITTER) llInstantMessage(g_kFisher, "You failed to provide the correct answer.");
            if (NOTICE_OWNER) llOwnerSay(llKey2Name(g_kFisher)+" failed to provide the correct answer.");
            llMessageLinked(LINK_SET, 0, OFID+"|unsit", NULL_KEY);
        }
    }
}