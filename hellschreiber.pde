/*
A meager attempt at a Feld Hell decoder program, with
 the end goal of TX/RX in a cross-platform, user-friendly form.
 
 ...Notes about the concept...
 Receive is 7 scan lines per character, 14 pixels per scan line.
 
    I   II  III IV  V   VI  VII  
 7  :   :   :   :   :   :   :   -  <- 57.14/14 = 4.08ms per pixel
 6  :   :   :   :   :   :   :   |
 5  :   :   :   :   :   :   :   |
 4  :   :   :   :   :   :   :   400/7 = 57.14ms
 3  :   :   :   :   :   :   :   |
 2  :   :   :   :   :   :   :   |
 1  :   :   :   :   :   :   :   -
 <======== 400ms ==========>
 ^400/7 = 57.14ms per scan line
 
 SR = Sample Rate (probably 8000/second = 0.125ms/sample)
 
 Buffer length of 1024 (div by 8000) gives about
 128ms per buffer = ~31px = 2.24 scan lines.
 
 At a sample rate of 8000, need 65.28 samples per 2 pixels.
 32.64 samples per pixel
 
 1 sample = 0.125ms = 1/sampleRate
 
 400ms/char at 0.125ms/sample = 3200samples/char
 400ms/char * sampleRate = samples/char
 
 samples/char/7lines/14pixels = 32.653samples/pixel
 */
 
 
import controlP5.*;
ControlP5 cp5;
//Slider msPerCharSlider;
//int msPerCharSlider;

import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.ugens.*;
Minim minim;
AudioInput in;
AudioPlayer player;
AudioProcessor audio;
AudioOutput out;
Oscil osc;

import ddf.minim.signals.*;
// we must import this package to create an AudioFormat object
import javax.sound.sampled.*;

int bufferSize = 1024;

void settings()
{
  //size(displayWidth, displayHeight);
  fullScreen();
  //size(2000, 1200);
  //pixelDensity(displayDensity()/2);

}

void setup()
{
  cp5 = new ControlP5(this);
  cp5.addSlider("msPerCharSlider")
     .setPosition(100,500)
     .setSize(400,40)
     .setRange(300,500)
     .setValue(400)
     .getValueLabel().setSize(20)
     ;
  cp5.addButton("press")
     .setPosition(600, 500)
     .setSize(80,80)
     .setValue(0)
     ;
  //cp5.getController("msPerCharSlider").getValueLabel().setSize(20);

  
  minim = new Minim(this);
  in = minim.getLineIn(1,1024,44100);
  audio = new AudioProcessor(in.bufferSize(), in.sampleRate());
  in.addListener(audio);
  out = minim.getLineOut();
  
  
  //player = minim.loadFile("a.wav", bufferSize);
  //player.loop(1);
  //output = createWriter("o.txt");
  //WaveformSaver ws = new WaveformSaver();
  //player.addListener(ws);
  
  
}
PrintWriter output;

void draw()
{
  audio.draw();
}

//void keyPressed() {
  //output.flush();
  //output.close();
  //if( key == ESC ) {
  //  exit();
  //} else {
  //  if( audio != null) {
  //    audio.transmitChar(key);
  //  }
  //}
//}

void msPerCharSlider(float val) {
  if( audio != null ) {
	println("Setting msPerChar to " + val);
    audio.setMsPerChar(val);
  }
}
void bandSlider(int val) {
  if( audio != null ) {
    audio.setBand(val);
  }
}
void thresholdSlider(float val) {
  if( audio != null ) {
    audio.setThreshold(val);
  }
}
void bandWidthSlider(int val) {
  if( audio != null ) {
    audio.setBandWidth(val);
  }
}
void press(int val) {
  if( audio != null ) {
    audio.transmitString("A");
  }
}
void transmitFrequencySlider(int val) {
  if( audio != null ) {
    audio.setTransmitFrequency(val);
  }
}
void transmitStringBox(String text) {
  if( audio != null ) {
    audio.transmitString(text);
  }
}


// AudioListener is attached to an AudioPlayer or AudioInput
// samples() is called every time the attached object has new samples
class AudioProcessor implements AudioListener
{
  private float[] left;
  private float[] right;
  private FFT fft;
  private PGraphics decodeGraphics;
  private PGraphics decodeGraphicsHistory;
  private PGraphics spectrumGraphics;
  private PVector decodeGraphicsPosition;
  private PVector spectrumGraphicsPosition;
  //private int x=0, y=0, counter=0;
  private int startTime;
  private float msPerChar = 400;
  private int scanLinesPerChar = 7;
  private int pixelsPerLine = 14;
  private float msPerPixel = (float)msPerChar / scanLinesPerChar / pixelsPerLine;
  private float samplesPerPixel;
  private float[] onePixelSamples;
  private int pixelIndex = 0;
  private int onePixelIndex = 0;
  private float msTo; // TODO: rename this
  private float sampleRate;
  private int band;
  private int bandWidth;
  private float transmitFrequency;
  private float threshold = 4;
  private int pixelSize = 5;
  private AudioSample outputSamples;
  private int pixelSamplesLength;
  private HashMap<String,int[]> dictionary = new HashMap<String,int[]>();

  AudioProcessor(int timeSize, float sampleRateIn)
  {
    left = null; 
    right = null;
    sampleRate = sampleRateIn;
    //fft = new FFT(timeSize, sampleRate);
    decodeGraphics = createGraphics(width, pixelSize*pixelsPerLine);//timeSize, 2*(int)sampleRate);
    decodeGraphicsHistory = createGraphics(decodeGraphics.width, decodeGraphics.height);
    
    startTime = millis(); // TODO: may cause problems if program runs too long and exceeds int's maximum value
    msTo = startTime + pixelIndex * msPerPixel;

    samplesPerPixel = (sampleRate / 1000) * msPerPixel;
    onePixelSamples = new float[(int)pow(2, ceil(log(samplesPerPixel)/log(2))+1)];
    fft = new FFT(onePixelSamples.length, sampleRate);
    spectrumGraphics = createGraphics(width, pixelSize * fft.specSize());
    spectrumGraphicsPosition = new PVector(0, height - spectrumGraphics.height);
    decodeGraphicsPosition = new PVector(0, 0);
    band = 10;//int(0.2*fft.specSize());
    bandWidth = 1;
    transmitFrequency = 900;
    pixelSamplesLength = (int)msPerPixel * (int)sampleRate / 1000;
    
    dictionary.put("A",charA); dictionary.put("B",charB); dictionary.put("C",charC); dictionary.put("D",charD);
    dictionary.put("E",charE); dictionary.put("F",charF); dictionary.put("G",charG); dictionary.put("H",charH);
    dictionary.put("I",charI); dictionary.put("J",charJ); dictionary.put("K",charK); dictionary.put("L",charL);
    dictionary.put("M",charM); dictionary.put("N",charN); dictionary.put("O",charO); dictionary.put("P",charP);
    dictionary.put("Q",charQ); dictionary.put("R",charR); dictionary.put("S",charS); dictionary.put("T",charT);
    dictionary.put("U",charU); dictionary.put("V",charV); dictionary.put("W",charW); dictionary.put("X",charX);
    dictionary.put("Y",charY); dictionary.put("Z",charZ); dictionary.put("1",char1); dictionary.put("2",char2);
    dictionary.put("3",char3); dictionary.put("4",char4); dictionary.put("5",char5); dictionary.put("6",char6);
    dictionary.put("7",char7); dictionary.put("8",char8); dictionary.put("9",char9); dictionary.put("0",char0);
    
    cp5.addSlider("thresholdSlider")
       .setPosition(100,400)
       .setSize(600,40)
       .setRange(0,5)
       .setValue(threshold)
       .getValueLabel().setSize(20)
       ;
    //cp5.addSlider("bandSlider")
    //   .setPosition(0,spectrumGraphicsPosition.y)
    //   .setSize(40,spectrumGraphics.height)
    //   .setRange(0,fft.specSize())
    //   .setValue(band)
    //   .getValueLabel().setSize(20)
    //   ;
    cp5.addSlider("bandWidthSlider")
       .setPosition(100,600)
       .setSize(600,40)
       .setRange(1,10)
       .setValue(bandWidth)
       .setNumberOfTickMarks(10)
       .getValueLabel().setSize(20)
       ;
    cp5.addSlider("transmitFrequencySlider")
       .setPosition(width-40,spectrumGraphicsPosition.y)
       .setSize(40,spectrumGraphics.height)
       .setRange(50,1200)
       .setValue(transmitFrequency)
       .getValueLabel().setSize(20)
       ;
    cp5.addTextfield("transmitStringBox")
       .setPosition(100,700)
       .setSize(600,40)
       .getValueLabel().setSize(20)
       ;
    
    
    println("sampleRate " + sampleRate);
    println("onePixelSamples.length " + onePixelSamples.length);
    println("msPerPixel " + msPerPixel);
    println("samplesPerPixel " + samplesPerPixel);
    println("startTime " + startTime);
    println("msTo " + msTo);
    println("millis() " + millis());
    println("fft.specSize() " + fft.specSize());
  }

  public synchronized void setMsPerChar(float val) {
    msPerChar = val;
    msPerPixel = (float)msPerChar / scanLinesPerChar / pixelsPerLine;
        msTo = startTime + pixelIndex * msPerPixel;
    samplesPerPixel = (sampleRate / 1000) * msPerPixel;
    onePixelSamples = new float[(int)pow(2, ceil(log(samplesPerPixel)/log(2))+1)];
    fft = new FFT(onePixelSamples.length, sampleRate);
    spectrumGraphics = createGraphics(width, pixelSize * fft.specSize()); 
    //spectrumGraphicsPosition = new PVector(0, height - spectrumGraphics.height);

  }
  
  public void setBand(int val) {
    band = val;//(int)map(val, 0, 1, 0,fft.specSize()); 
  }
  
  public void setBandWidth(int val) {
    bandWidth = val; 
  }
  
  public void setThreshold(float val) {
    threshold = val;
  }
  public void setTransmitFrequency(float val) {
    transmitFrequency = val;
  }
  public void click(int x, int y) {
    if( x >= spectrumGraphicsPosition.x && x < spectrumGraphicsPosition.x + spectrumGraphics.width &&
        y >= spectrumGraphicsPosition.y && y < spectrumGraphicsPosition.y + spectrumGraphics.height && 
		cp5.getMouseOverList().size() == 0 ) {
      setBand((int)map(y,spectrumGraphicsPosition.y,spectrumGraphicsPosition.y + spectrumGraphics.height,fft.specSize(),0));
    }
  }
  public void transmitChar(char c) {
    char[] data = {c};  
    String s = new String(data).toUpperCase();
    transmitString(s);
  }
  public void transmitString(String in) {
    in = in.toUpperCase();
    for( int i = 0; i < in.length(); i++ ) {
      String sub = in.substring(i,i+1);
        float t = millis() + msPerChar;
      if( sub == " " ) {
        
      } else {
        int[] charBuffer = dictionary.get(sub);
        if( charBuffer != null ) {
          triggerOutput(charBuffer);
          println("Triggered " + sub + " at " + millis());
        } else {
          println("Did not find " + sub);
        }
      }
      while( t > millis() ) {} // wait for amount of time for blank space
    }
  }
  public void triggerOutput(int[] charPixels) {
    SineWave sine = new SineWave( transmitFrequency,
                                  1.0,  // amplitude
                                  44100 // sample rate
                                  );
    
    
    println("pixelSamplesLength " + pixelSamplesLength);
    float[] charSamples = new float[pixelSamplesLength * pixelsPerLine * scanLinesPerChar];
                          // ... equal to new float[(int)msPerChar * (int)sampleRate / 1000];  ???
    //sine.generate(charSamples);    // generate some audio - there will be a click at the end - TODO: fading
    //int[] charPixels = {0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1,0,0,1,1,1,0,0,0,0,0,0,0,1,1,0,0,0,1,1,0,0,0,0,0,0,0,1,1,0,0,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    sine.generate(charSamples); // carrier oscillator
    //println(charPixels);
    for( int i = 0; i < charPixels.length; i++ ) {
      //float[] pixelSamples = new float[pixelSamplesLength]; // TODO: probably a memory leak here
      if( charPixels[i] == 0 ) {
        for( int j = 0; j < pixelSamplesLength; j++ ) {
          charSamples[i * pixelSamplesLength + j] = 0;
        }
      }
      if( i > 0 ) { // ignore first pixel
        if( charPixels[i-1] != charPixels[i] ) { // if pixel changed state, fade in or out to eliminate clicks
          int len = 100;
          for(int j = 0; j < len; j++ ) {
            float multiplier = 0.5 * (-cos(map(j,0,len,0,PI))+1) * 0.7; // raised-cosine shaping
            if( charPixels[i] == 0 ) { // output just turned off
              charSamples[i * pixelSamplesLength - j] = charSamples[i * pixelSamplesLength - j] * multiplier;
            } else { // output just turned on
              charSamples[i * pixelSamplesLength + j] = charSamples[i * pixelSamplesLength + j] * multiplier;
            }
          }
        }
      }
      //arrayCopy(pixelSamples, 0, charSamples, pixelSamples.length * i, pixelSamples.length);
      //for( int j = 0; j < pixelSamplesLength; j++ ) {
      //  charSamples[i * pixelSamplesLength + j] = pixelSamples[j];
      //}
    }
    
    AudioFormat format = new AudioFormat( sampleRate, // sample rate
                                          16,    // sample size in bits
                                          1,     // channels
                                          true,  // signed
                                          true   // bigEndian
                                          );
    outputSamples = minim.createSample( charSamples, // the samples
                                        format,  // the format
                                        1024     // the output buffer size
                                        );
    outputSamples.trigger(); // plays the character buffer
    
    // Use the samples buffer to draw the waveforms
    //stroke(0);
    //float sc = 3;
    //int sh = 100;
    //for (int i = 0; i < charSamples.length - 1; i++)
    //{
    //  line(i/sc + sh, 900 - charSamples[i]*200, i/sc + sh +1, 900 - charSamples[i+1]*200);
    //}
    
    //int m = millis();
    //int waitTime = int(charSamples.length / sampleRate * 1000);
    //println("waitTime " + waitTime);
    //while(millis() < m + waitTime){}
    //outputSamples.trigger();
    //while(millis() < m + waitTime * 2){}
    //outputSamples.trigger();
    //while(millis() < m + waitTime * 3){}
    //outputSamples.trigger();
  }
  
  //public void setBand(int

  synchronized void samples(float[] samp)
  {
    left = samp;
    //                   
    // |------------|---------|--------|
    // startTime    msFrom    msNow    msTo
    //                                 startTime + pixelIndex * msPerPixel
    //
    decodeGraphics.beginDraw();
    spectrumGraphics.beginDraw();
    //decodeGraphics.loadPixels();
    for ( float s : samp )
    {
      onePixelSamples[onePixelIndex] = s;
      onePixelIndex++;
      int lastColumn = floor(pixelIndex / pixelsPerLine) % (width / pixelSize);
      while ( millis() > msTo || onePixelIndex > samplesPerPixel ) {
        // Current pixel position - scans down and across
        int line   = pixelsPerLine - 1 - floor(pixelIndex % pixelsPerLine);
        int column = floor(pixelIndex / pixelsPerLine) % (width / pixelSize);
        // TODO: Check if output has wrapped - probably here be bugs
        if( column == 0 && line == 0 ) {
        //if( column < lastColumn ) {
          decodeGraphics.loadPixels();
          decodeGraphicsHistory.beginDraw();
          decodeGraphicsHistory.loadPixels();
          for( int i = 0; i < decodeGraphics.width * decodeGraphics.height; i++ ) {
            decodeGraphicsHistory.pixels[i] = decodeGraphics.pixels[i];
          }
          //decodeGraphics.updatePixels();
          decodeGraphicsHistory.updatePixels();
          decodeGraphicsHistory.endDraw();
          println("Wrapped output");
        }

        fft.forward(onePixelSamples);
        
        // Get band values for all bands in bandWidth - uses band as lower bound,
        //   band + bandWidth for upper bound
        float[] bandValues = new float[bandWidth];// = fft.getBand(band);
        float bandValue = 0;
        for( int i = 0; i < bandWidth; i++ )
        {
          bandValues[i] = fft.getBand(band+i);
          bandValue += fft.getBand(band+i);
        }
        bandValue /= bandWidth;
        
        // Draw spectral view
        for( int i = 0; i < fft.specSize(); i++ ) {
		  
          spectrumGraphics.fill(map(fft.getBand(i), 0, 1, 0, 255));
          spectrumGraphics.stroke(map(fft.getBand(i), 0, 1, 0, 255));
          spectrumGraphics.rect(pixelSize*column, spectrumGraphics.height - pixelSize*i, pixelSize, pixelSize);
        }
        
        // Draw band lines
        //   Lower limit
        spectrumGraphics.stroke(255,0,0);
        spectrumGraphics.line(pixelSize* column   , spectrumGraphics.height - pixelSize*band,
                              pixelSize*(column+1), spectrumGraphics.height - pixelSize*band);
        //   Upper limit 
        spectrumGraphics.stroke(0,255,0);
        spectrumGraphics.line(pixelSize* column   , spectrumGraphics.height - pixelSize*(band+bandWidth),
                              pixelSize*(column+1), spectrumGraphics.height - pixelSize*(band+bandWidth));
        // Scan line in front of the spectrum
        spectrumGraphics.stroke(128,0,0);
        spectrumGraphics.line(pixelSize*(column+1), 0,
                              pixelSize*(column+1), spectrumGraphics.height);
        
        //spectrumGraphics.rect(pixelSize*column, spectrumGraphics.height - pixelSize*band, pixelSize, pixelSize);
        
        // Draw decoded text
        decodeGraphics.fill(map(bandValue, 0, threshold, 0, 255));
        decodeGraphics.rect(pixelSize*column, pixelSize*line, pixelSize, pixelSize);
        decodeGraphics.fill(0, 0, 255);
        decodeGraphics.rect(0, 0, pixelSize, pixelSize);
        //decodeGraphics.rect(pixelSize*column + pixelSize, pixelSize*line + pixelSize*pixelsPerLine, pixelSize, pixelSize);

        pixelIndex++;
        onePixelIndex = 0;
        msTo = startTime + pixelIndex * msPerPixel;
        for ( float i : onePixelSamples ) {
          i= 0;
        }
      }
    }
    //decodeGraphics.updatePixels();
    decodeGraphics.endDraw();
    spectrumGraphics.endDraw();
  }

  synchronized void samples(float[] sampL, float[] sampR)
  {
    samples(sampL); // Sets left = sampL and draws decoded output;
    //right = sampR;
  }

  synchronized void draw()
  {
    image(spectrumGraphics, spectrumGraphicsPosition.x, spectrumGraphicsPosition.y);
    image(decodeGraphics, decodeGraphicsPosition.x, decodeGraphicsPosition.y);
    image(decodeGraphics, decodeGraphicsPosition.x + pixelSize, decodeGraphicsPosition.y + decodeGraphics.height);
    image(decodeGraphicsHistory, decodeGraphicsPosition.x, decodeGraphicsPosition.y + 2*decodeGraphics.height);
    image(decodeGraphicsHistory, decodeGraphicsPosition.x, decodeGraphicsPosition.y + 3*decodeGraphics.height);
  }
}