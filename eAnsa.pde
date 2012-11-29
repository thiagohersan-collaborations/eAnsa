// Ventoinha 03 : Com Antenas !!
//
// Teste de antenas...
//

#define DEBUG 0

// pins for analog read
#define ANALOG0 0

// number of flops and first clock pin
#define NUM_CLKS 4
#define CLK0 10

// bits per flop and first bit pin
#define BPF 6
#define BIT0 2

// period at which we update the flops
#define TIME 1000


///////////
// pre-defined patterns

// max size of pattern+1
#define PSIZE 16

// Patterns should have same length for synchronizing interwoven patterns
// 
const short P[4][PSIZE] = {
  // clear pattern (probably not used, since memories don' get clocked unless they're active, but ....
  {
    0, 0, 0, 0, 0, 0, 0, 0,0, 0, 0, 0,-1,0,0,0                                                 },

  // test patterns
  {
    1, 3, 6,12,24,48,32, 0,0, 0, 0, 0,-1,0,0,0                                                 },
  {
    32,0, 0, 0, 0, 0, 1, 3,6,12,24,48,-1,0,0,0                                                 },

  // simple pattern
  {
    3, 6,12,24,48,-1, -1, 0,0, 0, 0, 0,-1,0,0,0                                                 }


};


// sequence arrays 
short V[NUM_CLKS][PSIZE];

// index into V arrays.
// also, -1 if not playing array
short I[NUM_CLKS];

// max sections allowed to run at once
// depends on how many columns we turn on at a time, per section
// 4 only if we have interwoven patterns.... with lots of 0s...
// this will probably be 2...
#define MAXSEC 2

// how many of the 4 sections are active
unsigned short sec_count;

//// sensors
//

// length of running average
#define AVGSIZE 16

// array for keeping values read from sensors
unsigned int    VALS[NUM_CLKS][AVGSIZE];

// array to keep indexes for VALS array.
// we can use the same index for all of them, since we
// will always be updating all the running averages all the time,
// but this is safer.
unsigned short IVALS[NUM_CLKS];

// running sums of values from sensors
unsigned int    SUMS[NUM_CLKS];

// arrays for keeping min/max average for each sensor
unsigned int MAXQ[NUM_CLKS];
unsigned int MINQ[NUM_CLKS];

// cycle counter
unsigned short cycle_count;

void setup() {

  sec_count = cycle_count = 0;

  // zero all indexes
  for(short i=0; i<NUM_CLKS; i++) {
    I[i] = -1;
  }

  // zero V arrays
  for(int i=0; i<NUM_CLKS; i++) {
    for(int j=0; j<PSIZE; j++) {
      V[i][j] = P[0][j];
    }
  }

  // zero the clock signals...
  for(int clk=(NUM_CLKS-1); clk>=0; clk--) {
    pinMode(CLK0+clk, OUTPUT);  
    digitalWrite(CLK0+clk,LOW);
  }

  // zero the flop inputs
  for (int j=0; j<BPF; j++) {
    pinMode(BIT0+j, OUTPUT);  
    digitalWrite(BIT0+j,LOW);
  }

  // clock zeros into flops
  for(int clk=(NUM_CLKS-1); clk>=0; clk--) {
    digitalWrite(CLK0+clk,HIGH);
    delay(50);
    digitalWrite(CLK0+clk,LOW);
  }

  //////
  // sensors...
  //////

  // zero all sums, mins, maxs, indexes, and val arrays
  for(int i=0; i<NUM_CLKS; i++) {
    SUMS[i] = 0;
    MAXQ[i] = 0;
    MINQ[i] = 1024;

    IVALS[i] = 0;

    for(int j=0; j<AVGSIZE; j++){
      VALS[i][j] = analogRead(ANALOG0+i);
      SUMS[i] += VALS[i][j];
    }
  }




  // take running average for a few seconds to calculate min and max values from sensors
  unsigned int temp_time = millis();

  while((millis()-temp_time) < 1000) {

    // update running sum by
    //    subtracting oldest value from sum,
    //    reading new value into its place in the array, and adding it to sum,
    //    updating index
    // also update min/max averages
    for(int i=0; i<NUM_CLKS; i++) {
      SUMS[i] -= VALS[i][IVALS[i]];
      VALS[i][IVALS[i]] = analogRead(ANALOG0+i);
      SUMS[i] += VALS[i][IVALS[i]];

      // update index
      IVALS[i] = (IVALS[i]+1)%AVGSIZE;

      unsigned int avg = SUMS[i]/AVGSIZE;

      if(avg > MAXQ[i])
        MAXQ[i] = avg;
      if(avg < MINQ[i])
        MINQ[i] = avg;
    }

  }

  // debug
  if (DEBUG == 1) {
    Serial.begin(9600);

    for(int i=0; i<NUM_CLKS; i++) {
      Serial.print("min,max(");
      Serial.print(i);
      Serial.print("):  ");
      Serial.print(MINQ[i]);
      Serial.print(" ,  ");
      Serial.print(MAXQ[i]);
      Serial.println("\n");
    }

  }

}   // setup()


void loop() {

  // at every P millis, load a new number onto flops...
  if(millis()/TIME != cycle_count) {
    cycle_count = millis()/TIME;


    // i = NUM_CLKS --> 0   because of how we wired the memories to the arduino
    //     and because of how we attached the boards to the dress...
    for(int i=(NUM_CLKS-1); i>=0; i--) {

      // if this section is active... do some stuff
      // else do nothing (?????)
      if(I[i] > -1) {

        // whatever number is in this index hasn't been processed yet...
        short temp = V[i][(I[i])];

        // if value is -1, we're at the end of a pattern : stop pattern
        //   clear array
        //   clear memory
        //   decrease sc
        //   put index at -1
        if(temp == -1) {
          // clear index
          I[i] = -1;

          // clear array
          for(int j=0; j<PSIZE; j++){
            V[i][j] = P[0][j];
          }

          // clear arduino pins
          for (int j=0; j<BPF; j++) {
            digitalWrite(BIT0+j,LOW);
          }
          // send clock signal and load 0's into memory
          digitalWrite(CLK0+i,HIGH);
          delay(50);
          digitalWrite(CLK0+i,LOW);

          // decrease section count
          sec_count -= 1;
        }

        // active and in the middle of a pattern
        //    load present number into memory
        //    update index
        else {

          // iterate over bits and set arduino pins
          for (int j=0; j<BPF; j++) {
            short thisBit = ((temp>>j)&0x1);
            digitalWrite(BIT0+j,(thisBit==0)?LOW:HIGH);
          }
          // send clock signal and load memory
          digitalWrite(CLK0+i,HIGH);
          delay(50);
          digitalWrite(CLK0+i,LOW);

          // paranoia : iterate over bits and set arduino pins to 0
          for (int j=0; j<BPF; j++) {
            digitalWrite(BIT0+j,LOW);
          }

          // we know that temp != -1, so assume we're not at the last element, 
          // and we can just +1 the index
          I[i] = I[i] + 1;
        }

      }

    }

  }


  // at always...  
  //     check sensors, and update the running average
  for(int i=0; i<NUM_CLKS; i++) {
    SUMS[i] -= VALS[i][IVALS[i]];
    VALS[i][IVALS[i]] = analogRead(ANALOG0+i);
    SUMS[i] += VALS[i][IVALS[i]];

    // update index
    IVALS[i] = (IVALS[i]+1)%AVGSIZE;
  }




  // at always... 
  // if num of active sections sec_count < MAXSEC
  // check antenas for new signals
  // if new signal (cell phone present and the section is off), 
  //    load pattern into V
  //    update sec_counter
  //    change index at section to 0 so code above can start the pattern


  if((DEBUG == 1)) {
    for(int i=0; i<NUM_CLKS; i++) {
      unsigned int avg = SUMS[i]/AVGSIZE;
      if((avg > (MAXQ[i]+16)) || (avg < (MINQ[i]-16))) {

        Serial.print("(");
        Serial.print(i);
        Serial.print("):  ");
        Serial.print(avg);
        Serial.print("\n");

      }
    }
  }

/*
  Serial.print( 0xff, BYTE);
  Serial.print( (avg >> 8) & 0xff, BYTE);
  Serial.print( avg & 0xff, BYTE);
*/


  if(DEBUG == 0) {

    // if less than MAXSEC check current running average signals...
    if(sec_count < MAXSEC){

      // check current running average
      // if section off and (avg<min or avg>max) : turn it on
      for(int i=(NUM_CLKS-1); (i>=0)&&(sec_count<MAXSEC); i--) {

        unsigned int avg = SUMS[i]/AVGSIZE;

        // if this section is off and there's cell phone : turn section on
        //     load pattern into V
        //     update index
        //     sec_count++
        if( (I[i] == -1) && ((avg > (MAXQ[i]+16))||(avg < (MINQ[i]-16))) ) { 

          // load pattern
          // right now this is a test pattern
          for(int j=0; j<PSIZE; j++){
            V[i][j] = P[3][j];
          }

          // turn itself on by updating index
          // (code above will deal with the rest)
          // here because I[i]==-1, so make it 0. 
          I[i] = I[i] + 1;

          // update section counter
          sec_count += 1;
        }
      }

    }

  }


}   // loop()


















