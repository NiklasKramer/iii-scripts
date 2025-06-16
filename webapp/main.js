let params = {
  a: 3,
  b: 2,
  delta: 0,
  amp: 200
};

function setup() {
  createCanvas(windowWidth, windowHeight);
  stroke(0, 255, 150);
  noFill();
}

function draw() {
  background(0, 20);
  translate(width / 2, height / 2);
  beginShape();
  for (let t = 0; t < TWO_PI; t += 0.01) {
    let x = params.amp * sin(params.a * t + params.delta);
    let y = params.amp * sin(params.b * t);
    vertex(x, y);
  }
  endShape();
}

function windowResized() {
  resizeCanvas(windowWidth, windowHeight);
}

if (navigator.requestMIDIAccess) {
  navigator.requestMIDIAccess().then(function (midi) {
    midi.inputs.forEach(function (inp) {
      inp.onmidimessage = handleMIDI;
    });
    midi.onstatechange = function (e) {
      if (e.port.type === 'input') {
        e.port.onmidimessage = handleMIDI;
      }
    };
  });
}

function handleMIDI(e) {
  const data = e.data;
  const type = data[0] & 0xf0;
  if (type === 0xb0) {
    switch (data[1]) {
      case 1:
        params.a = 1 + Math.floor(data[2] / 16);
        break;
      case 2:
        params.b = 1 + Math.floor(data[2] / 16);
        break;
      case 3:
        params.delta = map(data[2], 0, 127, 0, TWO_PI);
        break;
      case 4:
        params.amp = map(data[2], 0, 127, 50, min(width, height) / 2 - 20);
        break;
    }
  }
}
