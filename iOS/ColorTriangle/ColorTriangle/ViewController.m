//
//  ViewController.m
//  ColorTriangle
//
//  Created by organlounge on 2013/04/08.
//  Copyright (c) 2013年 KAMEDAkyosuke. All rights reserved.
//

#import "ViewController.h"

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <QuartzCore/QuartzCore.h>

#import "Shaders.h"
#import "matrix.h"

enum {
	UNIFORM_MODELVIEW_MATRIX = 0,
	UNIFORM_PROJECTION_MATRIX,
	NUM_UNIFORMS
};

// attribute index
enum {
	ATTRIB_VERTEX_POSITION = 0,
	ATTRIB_VERTEX_COLOR,
	NUM_ATTRIBUTES
};

typedef struct {
    GLfloat Position[4];
    GLfloat Color[4];
} Vertex;

const Vertex Vertices[] = {
    {{ 0.0f,  1.0f,  0.0f}, { 1.0f, 0.0f, 0.0f, 1.0f}},
    {{-1.0f, -1.0f,  0.0f}, { 0.0f, 1.0f, 0.0f, 1.0f}},
    {{ 1.0f, -1.0f,  0.0f}, { 0.0f, 0.0f, 1.0f, 1.0f}}
};

const GLubyte Indices[] = {
    0, 1, 2,
};

@interface GLView : UIView
{
    GLuint _renderBuffer;
    GLuint _frameBuffer;
    GLuint _program;
    GLint  _uniforms[NUM_UNIFORMS];
    
}
@property(nonatomic, assign) CAEAGLLayer *eaglLayer;
@property(nonatomic, retain) EAGLContext *context;

@end

@implementation GLView

- (void) dealloc
{
    // TODO:
    [super dealloc];
}

+ (Class) layerClass
{
    return [CAEAGLLayer class];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self != nil){
        [self setupLayer];
        [self setupContext];
        [self setupRenderBuffer];
        [self setupFrameBuffer];
        [self setupShaders];
        [self setupVBOs];
        [self render];
    }
    return self;
}

- (void) setupLayer
{
    _eaglLayer = (CAEAGLLayer*)self.layer;
    _eaglLayer.opaque = YES;
    _eaglLayer.drawableProperties =@{ kEAGLDrawablePropertyColorFormat     : kEAGLColorFormatRGBA8,
                                      kEAGLDrawablePropertyRetainedBacking : @NO };
}

- (void) setupContext
{
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    self.context = [[[EAGLContext alloc] initWithAPI:api] autorelease];
    if (! _context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    if (! [EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

- (void)setupRenderBuffer {
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
}

- (void)setupFrameBuffer {
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER,  GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _renderBuffer);
}

- (BOOL)setupShaders {
	
	GLuint vertShader, fragShader;
	NSString *vertShaderPathname, *fragShaderPathname;
	
	// create shader program
	_program = glCreateProgram();
	
	// create and compile vertex shader
	vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"VertexShader" ofType:@"glsl"];
	if (!compileShader(&vertShader, GL_VERTEX_SHADER, 1, vertShaderPathname)) {
		// destroyShaders(vertShader, fragShader, _program);
        glDeleteShader(vertShader);
		vertShader = 0;
        glDeleteProgram(_program);
		return NO;
	}
	
	// create and compile fragment shader
	fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"FragmentShader" ofType:@"glsl"];
	if (!compileShader(&fragShader, GL_FRAGMENT_SHADER, 1, fragShaderPathname)) {
		destroyShaders(vertShader, fragShader, _program);
		return NO;
	}
	
	// attach vertex shader to program
	glAttachShader(_program, vertShader);
	
	// attach fragment shader to program
	glAttachShader(_program, fragShader);
	
	// bind attribute locations
	// this needs to be done prior to linking
	glBindAttribLocation(_program, ATTRIB_VERTEX_POSITION, "aVertexPosition");
	glBindAttribLocation(_program, ATTRIB_VERTEX_COLOR, "aVertexColor");
	
	// link program
	if (!linkProgram(_program)) {
		destroyShaders(vertShader, fragShader, _program);
		return NO;
	}
	
	// get uniform locations
	_uniforms[UNIFORM_MODELVIEW_MATRIX] = glGetUniformLocation(_program, "uMVMatrix");
	_uniforms[UNIFORM_PROJECTION_MATRIX] = glGetUniformLocation(_program, "uPMatrix");
	
	// release vertex and fragment shaders
	if (vertShader) {
		glDeleteShader(vertShader);
		vertShader = 0;
	}
	if (fragShader) {
		glDeleteShader(fragShader);
		fragShader = 0;
	}
	return YES;
}

- (void)setupVBOs {
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    GLuint indexBuffer;
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
}

- (void)render {
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    
    glClearColor(0.9f, 0.9f, 0.9f, 1.0f);;
    glClear(GL_COLOR_BUFFER_BIT);
    
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    
    // use shader program
	glUseProgram(_program);
    
    // handle viewing matrices
	GLfloat mvMatrix[16];
    GLfloat pMatrix[16];
    mat4f_LoadPerspective(45, self.frame.size.width/self.frame.size.height, 0.1f, 100.0f, pMatrix);
    mat4f_LoadIdentity(mvMatrix);
    float translation[] = {0.0f, 0.0f, -3.0f};
    mat4f_LoadTranslation(translation, mvMatrix);
    
	glUniformMatrix4fv(_uniforms[UNIFORM_MODELVIEW_MATRIX], 1, GL_FALSE, mvMatrix);
	glUniformMatrix4fv(_uniforms[UNIFORM_PROJECTION_MATRIX], 1, GL_FALSE, pMatrix);
	
    glVertexAttribPointer(ATTRIB_VERTEX_POSITION, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), 0);
	glEnableVertexAttribArray(ATTRIB_VERTEX_POSITION);
    
    glVertexAttribPointer(ATTRIB_VERTEX_COLOR, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void *)(sizeof(GLfloat) * 4));
    glEnableVertexAttribArray(ATTRIB_VERTEX_COLOR);

    glDrawElements(GL_TRIANGLES, 3, GL_UNSIGNED_BYTE, 0);
    
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

@end

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
