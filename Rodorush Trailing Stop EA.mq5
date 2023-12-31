//+------------------------------------------------------------------+
//|                                        TrailingStop (v.1.00).mq5 |
//|                                       Rodolfo Pereira de Andrade |
//|                                    https://rodorush.blogspot.com |
//+------------------------------------------------------------------+
#property copyright "Rodolfo Pereira de Andrade"
#property link      "https://rodorush.blogspot.com.br"
#property version   "1.00"

double pSar[];
ENUM_TIMEFRAMES periodo;
int pSarHandle;

MqlRates rates[];
MqlTradeRequest myRequest = {};
MqlTradeResult myResult = {};

string robot = "TrailingStop 1.00"; //Nome do EA
string simbolo;

input group "Parabolic SAR"
input double step = 0.02; //Passo
input double maximum = 0.2; //Máximo

input group "Horário de Funcionamento"
input int startHour = 9; //Hora de início dos trades
sinput int startMinutes = 00; //Minutos de início dos trades
input int stopHour = 17; //Hora de interrupção dos trades
sinput int stopMinutes = 50; //Minutos de interrupção dos trades

int OnInit() {
   if(startHour > stopHour) return(INIT_PARAMETERS_INCORRECT);
   
   ArraySetAsSeries(pSar,true);
   ArraySetAsSeries(rates,true);

   simbolo = ChartSymbol(0);
   periodo = ChartPeriod(0);

   CopyRates(simbolo, periodo, 0, 2, rates);

   myRequest.symbol = simbolo;
   myRequest.deviation = 0;
   myRequest.type_filling = ORDER_FILLING_RETURN;
   myRequest.type_time = ORDER_TIME_DAY;
   myRequest.comment = robot;
   
   return(INIT_SUCCEEDED);
}

void OnTick() {
   int bars = Bars(simbolo, periodo);
   CopyRates(simbolo, periodo, 0, 2, rates);

   if(!TimeSession(startHour,startMinutes,stopHour,stopMinutes,TimeCurrent())) { //Hora para fechar posições
      FechaPosicao();
      Comment("Fora do horário de trabalho. EA dormindo...");
   }else Comment("");
   
   if(NovaVela(bars)) {
      IndBuffers();
      if(PositionGetTicket(0) > 0) TrailingStop(); else ExpertRemove();
   }
}

void OnDeinit(const int reason) {
   MessageBox("Terminamos por aqui... muito obrigado e volte sempre!","TrainlingStop Finalizado",0);
}

void IndBuffers() {
   pSarHandle = iSAR(simbolo,periodo,step,maximum);
   
   CopyBuffer(pSarHandle,0,0,3,pSar);
}

void TrailingStop() {
   double stopLoss = PositionGetDouble(POSITION_SL);
   double tStop;

   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
      tStop = MathFloor(pSar[1]/5)*5;
      if(tStop > stopLoss && tStop < rates[1].low) myRequest.sl = tStop; else return;
   }else {
      tStop = MathCeil(pSar[1]/5)*5;
      if(tStop < stopLoss && tStop > rates[1].high) myRequest.sl = tStop; else return;
   }
   myRequest.position = PositionGetTicket(0);
   myRequest.action = TRADE_ACTION_SLTP;
   
   Print("Acionando Trailing Stop...");
   if(!OrderSend(myRequest,myResult)) Print("Envio de ordem Trailing Stop falhou. Erro = ",GetLastError());

}

void FechaPosicao() {
   ulong positionTicket = PositionGetTicket(0);
   
   if(positionTicket > 0) {
      long positionType = PositionGetInteger(POSITION_TYPE);
      
      myRequest.action = TRADE_ACTION_DEAL;
      myRequest.volume = PositionGetDouble(POSITION_VOLUME);
      myRequest.type = (positionType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      myRequest.price = (positionType == POSITION_TYPE_BUY) ? SymbolInfoDouble(simbolo,SYMBOL_BID) : SymbolInfoDouble(simbolo,SYMBOL_ASK);
      Print("Fechando posição...");
      if(!OrderSend(myRequest,myResult)) Print("Envio de ordem Fechamento falhou. Erro = ",GetLastError());
   }
   
}

bool NovaVela(int bars) {
   static int lastBars = 0;
   
   if(bars>lastBars) {
      lastBars = bars;
      return(true);
   }
   return(false);
}

bool TimeSession(int aStartHour,int aStartMinute,int aStopHour,int aStopMinute,datetime aTimeCur) {
//--- session start time
   int StartTime=3600*aStartHour+60*aStartMinute;
//--- session end time
   int StopTime=3600*aStopHour+60*aStopMinute;
//--- current time in seconds since the day start
   aTimeCur=aTimeCur%86400;
   if(StopTime<StartTime)
     {
      //--- going past midnight
      if(aTimeCur>=StartTime || aTimeCur<StopTime)
        {
         return(true);
        }
     }
   else
     {
      //--- within one day
      if(aTimeCur>=StartTime && aTimeCur<StopTime)
        {
         return(true);
        }
     }
   return(false);
}
//+------------------------------------------------------------------+