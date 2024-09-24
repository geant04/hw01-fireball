import {vec3, vec4} from 'gl-matrix';
const Stats = require('stats-js');
import * as DAT from 'dat.gui';
import Icosphere from './geometry/Icosphere';
import Square from './geometry/Square';
import Cube from './geometry/Cube';
import OpenGLRenderer from './rendering/gl/OpenGLRenderer';
import Camera from './Camera';
import {setGL} from './globals';
import ShaderProgram, {Shader} from './rendering/gl/ShaderProgram';


// Define an object with application parameters and button callbacks
// This will be referred to by dat.GUI's functions that add GUI elements.
const controls = {
  tesselations: 5,
  flameColor: [255, 104, 0],
  secondFlameColor: [255, 255, 0],
  flameTipColor: [255, 255, 255],
  persistence: 0.5,
  amplitude: 0.5,
  frequency: 2.0,
  lacunarity: 2.0,
  octaves: 8,
  cube: false,
  partyTime: false,
  kaboomSpeed: 0.1,
  'Load Scene': loadScene, // A function pointer, essentially
};

let icosphere: Icosphere;
let square: Square;
let prevTesselations: number = 5;
let cube: Cube;
let start: number;

function loadScene() {
  icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, controls.tesselations);
  icosphere.create();
  square = new Square(vec3.fromValues(0, 0, 0));
  square.create();
  cube = new Cube(vec3.fromValues(0, 0, 0));
  cube.create();
}

function main() {
  // Initial display for framerate
  const stats = Stats();
  stats.setMode(0);
  stats.domElement.style.position = 'absolute';
  stats.domElement.style.left = '0px';
  stats.domElement.style.top = '0px';
  document.body.appendChild(stats.domElement);

  // Add controls to the gui
  const gui = new DAT.GUI();
  gui.add(controls, 'tesselations', 0, 8).step(1);
  gui.addColor(controls, 'flameColor');
  gui.addColor(controls, 'secondFlameColor');
  gui.addColor(controls, 'flameTipColor');
  gui.add(controls, 'persistence', 0.0, 1.0);
  gui.add(controls, 'amplitude', 0.0, 1.0);
  gui.add(controls, 'frequency', 0.0, 10.0);
  gui.add(controls, 'lacunarity', 0.0, 10.0);
  gui.add(controls, 'octaves', 0, 10).step(1);
  gui.add(controls, 'cube', false);
  gui.add(controls, 'partyTime', false);
  gui.add(controls, 'kaboomSpeed', 0.0, 0.5);
  gui.add(controls, 'Load Scene');

  // get canvas and webgl context
  const canvas = <HTMLCanvasElement> document.getElementById('canvas');
  const gl = <WebGL2RenderingContext> canvas.getContext('webgl2');
  if (!gl) {
    alert('WebGL 2 not supported!');
  }
  // `setGL` is a function imported above which sets the value of `gl` in the `globals.ts` module.
  // Later, we can import `gl` from `globals.ts` to access it
  setGL(gl);

  // Initial call to load scene
  loadScene();

  const camera = new Camera(vec3.fromValues(0, 0, 5), vec3.fromValues(0, 0, 0));

  const renderer = new OpenGLRenderer(canvas);
  renderer.setClearColor(0.05, 0.05, 0.05, 1);
  gl.enable(gl.DEPTH_TEST);
  gl.enable(gl.BLEND);
  gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

  const lambert = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/fireball-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/fireball-frag.glsl')),
  ]);

  const backgroundShader = new ShaderProgram([
    new Shader(gl.VERTEX_SHADER, require('./shaders/lambert-vert.glsl')),
    new Shader(gl.FRAGMENT_SHADER, require('./shaders/lambert-frag.glsl')),
  ]);

  // This function will be called every frame
  function tick(timeStamp: number) {
    if (start == undefined)
    {
      start = timeStamp;
    }

    const elapsed = timeStamp - start;

    camera.update();
    stats.begin();
    gl.viewport(0, 0, window.innerWidth, window.innerHeight);
    renderer.clear();
    if(controls.tesselations != prevTesselations)
    {
      prevTesselations = controls.tesselations;
      icosphere = new Icosphere(vec3.fromValues(0, 0, 0), 1, prevTesselations);
      icosphere.create();
    }

    let geomColor = vec4.fromValues(
                        controls.flameColor[0] / 255.0,
                        controls.flameColor[1] / 255.0,
                        controls.flameColor[2] / 255.0,
                        1.0,
                      );
    let secondFlameColor = vec4.fromValues(
                        controls.secondFlameColor[0] / 255.0,
                        controls.secondFlameColor[1] / 255.0,
                        controls.secondFlameColor[2] / 255.0,
                        1.0,
                      );
    
    let flameTipColor = vec4.fromValues(
                        controls.flameTipColor[0] / 255.0,
                        controls.flameTipColor[1] / 255.0,
                        controls.flameTipColor[2] / 255.0,
                        1.0,
                      );
    
    let progs = [lambert, backgroundShader];

    progs.forEach((prog) => {
      prog.setFloat("u_Persistence", controls.persistence);
      prog.setFloat("u_Amplitude", controls.amplitude);
      prog.setFloat("u_Frequency", controls.frequency);
      prog.setFloat("u_Lacunarity", controls.lacunarity);
      prog.setFloat("u_Time", timeStamp / 1000.0);
      prog.setFloat("u_KaboomSpeed", controls.kaboomSpeed);
      prog.setInt("u_Octaves", controls.octaves);
      prog.setInt("u_IsPartyTime", controls.partyTime ? 1 : 0);
      prog.setVec4("u_SecondFlameColor", secondFlameColor);
      prog.setVec4("u_FlameTipColor", flameTipColor);
    });

    let objects = []
    
    if (controls.cube) objects.push(cube)
    if (!controls.cube) objects.push(icosphere)
    
    gl.depthFunc(gl.ALWAYS)
    renderer.render(camera, backgroundShader, geomColor, [cube]);
    gl.depthFunc(gl.LESS)
    renderer.render(camera, lambert, geomColor, objects);

    stats.end();

    // Tell the browser to call `tick` again whenever it renders a new frame
    requestAnimationFrame(tick);
  }

  window.addEventListener('resize', function() {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.setAspectRatio(window.innerWidth / window.innerHeight);
    camera.updateProjectionMatrix();
  }, false);

  renderer.setSize(window.innerWidth, window.innerHeight);
  camera.setAspectRatio(window.innerWidth / window.innerHeight);
  camera.updateProjectionMatrix();

  // Start the render loop
  tick(0.0);
}

main();
