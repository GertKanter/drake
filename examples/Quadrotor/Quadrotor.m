classdef Quadrotor < RigidBodyManipulator
  
  methods
    
    function obj = Quadrotor(sensor)
      if nargin<1, sensor=''; end
      options.floating = true;
      options.terrain = RigidBodyFlatTerrain();
      w = warning('off','Drake:RigidBodyManipulator:ReplacedCylinder');
      warning('off','Drake:RigidBodyManipulator:UnsupportedContactPoints');
      obj = obj@RigidBodyManipulator('quadrotor.urdf',options);
      warning(w);
      
      switch (sensor)
        case 'lidar'
          obj = addFrame(obj,RigidBodyFrame(findLinkInd(obj,'base_link'),[.35;0;0],zeros(3,1),'lidar_frame'));
          lidar = RigidBodyLidar('lidar',findFrameId(obj,'lidar_frame'),-.4,.4,40,10);
          lidar = enableLCMGL(lidar);
          obj = addSensor(obj,lidar);
        case 'kinect'
          obj = addFrame(obj,RigidBodyFrame(findLinkInd(obj,'base_link'),[.35;0;0],zeros(3,1),'kinect_frame'));
          kinect = RigidBodyDepthCamera('kinect',findFrameId(obj,'kinect_frame'),-.4,.4,12,-.5,.5,30,10);
          kinect = enableLCMGL(kinect);
          obj = addSensor(obj,kinect);
      end
      obj = addSensor(obj,FullStateFeedbackSensor);
      obj = compile(obj);
    end
   
    function u0 = nominalThrust(obj)
      % each propellor commands -mg/4
      u0 = Point(getInputFrame(obj),getMass(obj)*norm(getGravity(obj))*ones(4,1)/4);
    end
    
    function obj = addObstacles(obj,number_of_obstacles)
      if nargin<2, number_of_obstacles = randi(10); end
      
      for i=1:number_of_obstacles
        xy = randn(2,1);
        while(norm(xy)<1), xy = randn(2,1); end
        height = .5+rand;
        shape = RigidBodyBox([.2+.8*rand(1,2) height],[xy;height/2],[0;0;randn]);
        shape.c = rand(3,1);
        obj = addShapeToBody(obj,'world',shape);
        obj = addContactShapeToBody(obj,'world',shape);
      end
      
      obj = compile(obj);
    end
    
    function obj = addTrees(obj,number_of_obstacles)
      if nargin<2, number_of_obstacles = 5*(randi(5)+2); end
      for i=1:number_of_obstacles
        xy = 5*randn(2,1);
        while(norm(xy)<1 || (xy(2,1)<=1 && xy(2,1)>=-1)), xy = randn(2,1); end
        height = 1+rand;
        width_param = rand(1,2);
        yaw = randn;
        shape = RigidBodyBox([.2+.8*width_param height],[xy;height/2],[0;0;yaw]);
        shape.c = [83,53,10]/255;  % brown
        obj = addShapeToBody(obj,'world',shape);
        obj = addContactShapeToBody(obj,'world',shape);
        shape = RigidBodyBox(1.5*[.2+.8*width_param height/4],[xy;height + height/8],[0;0;yaw]);
        shape.c = [0,0.7,0];  % green
        obj = addShapeToBody(obj,'world',shape);
        obj = addContactShapeToBody(obj,'world',shape);
      end
      obj = compile(obj);
    end
    
    function traj_opt = addPlanVisualizer(obj,traj_opt)
      % spew out an lcmgl visualization of the trajectory.  intended to be
      % used as a callback (fake objective) in the direct trajectory
      % optimization classes

      if ~checkDependency('lcmgl')
        warning('lcmgl dependency is missing.  skipping visualization'); 
        return;
      end
      lcmgl = drake.util.BotLCMGLClient(lcm.lcm.LCM.getSingleton(), 'QuadrotorPlan');
      
      typecheck(traj_opt,'DirectTrajectoryOptimization');

      traj_opt = traj_opt.addDisplayFunction(@(x)visualizePlan(x,lcmgl),traj_opt.x_inds(1:3,:));
      
      function visualizePlan(x,lcmgl)
        lcmgl.glColor3f(1, 0, 0);
        lcmgl.glPointSize(3);
        lcmgl.points(x(1,:),x(2,:),x(3,:));
        lcmgl.glColor3f(.5, .5, 1);
        lcmgl.plot3(x(1,:),x(2,:),x(3,:));
        lcmgl.switchBuffers;
      end
    end
  end
  
  
  methods (Static)
    
    function runOpenLoop
      r = Quadrotor('lidar');
      r = addTrees(r); 
      sys = TimeSteppingRigidBodyManipulator(r,.01);
      
      v = sys.constructVisualizer();

      x0 = [0;0;.5;zeros(9,1)];
      u0 = nominalThrust(r);
      
      sys = cascade(ConstantTrajectory(u0),sys);

      sys = cascade(sys,v);
      simulate(sys,[0 2],double(x0)+.1*randn(12,1));
      
%      [ytraj,xtraj] = simulate(sys,[0 2],double(x0)+.1*randn(12,1));
%      v.playback(xtraj);
%      figure(1); clf; fnplt(ytraj);
    end
  end
end