function [ nativeScene ] = PBRTRemodellerFog( parentScene, nativeScene, mappings, names, conditionValues, conditionNumbers )

cameraType = rtbGetNamedValue(names,conditionValues,'type',[]);
lensType = rtbGetNamedValue(names,conditionValues,'lens',[]);
mode = rtbGetNamedValue(names,conditionValues,'mode',[]);
pixelSamples = rtbGetNamedNumericValue(names,conditionValues,'pixelSamples',[]);
filmDist = rtbGetNamedNumericValue(names,conditionValues,'filmDistance',[]);
filmDiag = rtbGetNamedNumericValue(names,conditionValues,'filmDiagonal',[]);
microlensDim = rtbGetNamedNumericValue(names,conditionValues,'microlens',[0, 0]);
fNumber = rtbGetNamedNumericValue(names,conditionValues,'fNumber',[]);
fog = rtbGetNamedValue(names,conditionValues,'fog','false');
diffraction = rtbGetNamedValue(names,conditionValues,'diffraction','true');
chromaticAberration = rtbGetNamedValue(names,conditionValues,'chromaticAberration','false');

environmentLight = MPbrtElement('LightSource','type','infinite');
environmentLight.setParameter('nsamples','integer',128);
environmentLight.setParameter('mapname','string','resources/sky.exr');
environmentLight.setParameter('scale','color',1000000000000000000*[1 1 1]);

nativeScene.world.append(environmentLight);


switch cameraType
    
    case 'perspective'
        camera = nativeScene.overall.find('Camera');
        camera.setParameter('fov','float',35);
        
    case 'pinhole'
        camera = nativeScene.overall.find('Camera');
        camera.parameters = [];
        camera.type = 'pinhole';
        camera.setParameter('filmdiag','float',filmDiag);
        camera.setParameter('filmdistance','float',filmDist);
        
    case 'lightfield'
        pos = strfind(lensType,'.');
        pos2 = strfind(lensType,'mm');
        fLength = lensType(pos(2)+1:pos2(1)-1);
        fLength = str2double(fLength);
        
        camera = nativeScene.overall.find('Camera');
        camera.type = 'realisticDiffraction';
        camera.parameters = [];
        camera.setParameter('aperture_diameter','float',fLength/fNumber);
        camera.setParameter('filmdiag','float',filmDiag);
        camera.setParameter('filmdistance','float',filmDist);
        camera.setParameter('num_pinholes_h','float',microlensDim(1));
        camera.setParameter('num_pinholes_w','float',microlensDim(2));
        camera.setParameter('microlens_enabled','float',0);
        camera.setParameter('diffractionEnabled','bool',diffraction);
        camera.setParameter('chromaticAberrationEnabled','bool',chromaticAberration);
        camera.setParameter('specfile','string',sprintf('resources/%s.dat',lensType));
        
    otherwise
        
        pos = strfind(lensType,'.');
        pos2 = strfind(lensType,'mm');
        fLength = lensType(pos(2)+1:pos2(1)-1);
        fLength = str2double(fLength);
        
        camera = nativeScene.overall.find('Camera');
        camera.type = 'realisticDiffraction';
        camera.parameters = [];
        camera.setParameter('aperture_diameter','float',fLength/fNumber);
        camera.setParameter('filmdiag','float',filmDiag);
        camera.setParameter('filmdistance','float',filmDist);
        camera.setParameter('num_pinholes_h','float',0);
        camera.setParameter('num_pinholes_w','float',0);
        camera.setParameter('microlens_enabled','float',0);
        camera.setParameter('diffractionEnabled','bool',diffraction);
        camera.setParameter('chromaticAberrationEnabled','bool',chromaticAberration);
        camera.setParameter('specfile','string',sprintf('resources/%s.dat',lensType));
        
end       
   

integrator = nativeScene.overall.find('SurfaceIntegrator');
sampler = nativeScene.overall.find('Sampler');
filter = nativeScene.overall.find('PixelFilter');


switch mode
    case {'depth'}
        integrator.type = 'metadata';
        integrator.parameters = [];
        integrator.setParameter('strategy','string','depth');
        
        sampler.type = 'stratified';
        sampler.parameters = [];
        sampler.setParameter('jitter','bool','false');
        sampler.setParameter('xsamples','integer',1);
        sampler.setParameter('ysamples','integer',1);
        sampler.setParameter('pixelsamples','integer',1);
        
        filter.type = 'box';
        filter.parameters = [];
        filter.setParameter('xwidth','float',0.5);
        filter.setParameter('ywidth','float',0.5);
        
    case {'material'}
        integrator.type = 'metadata';
        integrator.parameters = [];
        integrator.setParameter('strategy','string','material');
        
        sampler.type = 'stratified';
        sampler.parameters = [];
        sampler.setParameter('jitter','bool','false');
        sampler.setParameter('xsamples','integer',1);
        sampler.setParameter('ysamples','integer',1);
        sampler.setParameter('pixelsamples','integer',1);
        
        filter.type = 'box';
        filter.parameters = [];
        filter.setParameter('xwidth','float',0.5);
        filter.setParameter('ywidth','float',0.5);
        
    case {'mesh'}
        integrator.type = 'metadata';
        integrator.parameters = [];
        integrator.setParameter('strategy','string','mesh');
        
        sampler.type = 'stratified';
        sampler.parameters = [];
        sampler.setParameter('jitter','bool','false');
        sampler.setParameter('xsamples','integer',1);
        sampler.setParameter('ysamples','integer',1);
        sampler.setParameter('pixelsamples','integer',1);
        
        filter.type = 'box';
        filter.parameters = [];
        filter.setParameter('xwidth','float',0.5);
        filter.setParameter('ywidth','float',0.5);
        
    otherwise % Generate radiance data
        
        sampler.setParameter('pixelsamples','integer',pixelSamples);
        integrator.type = 'path';

        
        if strcmp(fog,'true');
            nativeScene.overall.find('SurfaceIntegrator','remove',true);
            volumeIntegrator = MPbrtElement('VolumeIntegrator','type','single');
            volumeIntegrator.setParameter('stepsize','float',50000);
            nativeScene.overall.append(volumeIntegrator);
        
        
            fogVolume = MPbrtElement('Volume','type','water');
            fogVolume.setParameter('p0','point','-100000000 -100000000 -10000000');
            fogVolume.setParameter('p1','point',sprintf('100000000 100000000 100000000'));
            fogVolume.setParameter('absorptionCurveFile','spectrum',sprintf('resources/abs.spd'));
            fogVolume.setParameter('phaseFunctionFile','string',sprintf('resources/phase.spd'));
            fogVolume.setParameter('scatteringCurveFile','spectrum',sprintf('resources/scat.spd'));
            nativeScene.world.append(fogVolume);
        end
        

        if (strcmp(chromaticAberration,'true') == 1) && (strcmp(cameraType,'pinhole') == 0)
            renderer = MPbrtElement('Renderer','type','spectralrenderer');
            nativeScene.overall.append(renderer);
        end

end







end


