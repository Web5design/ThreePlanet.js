define [
  'Three',
  'jquery',
  'text!../../../shaders/SkyFromSpace.vert',
  'text!../../../shaders/SkyFromSpace.frag',
  'text!../../../shaders/SkyFromAtmosphere.vert',
  'text!../../../shaders/SkyFromAtmosphere.frag',
  'text!../../../shaders/GroundFromSpace.vert',
  'text!../../../shaders/GroundFromSpace.frag',
  'jquery',
  'vendor/namespace',
], (_, Backbone, SkyFromSpaceVert, SkyFromSpaceFrag, SkyFromAtmosphereVert, SkyFromAtmosphereFrag, GroundFromSpaceVert, GroundFromSpaceFrag) ->
  ## Planet

  namespace "ThreePlanet.objects",
    settings:
      postprocessing: true
      backgroundColor: 0x000000

    PlanetShaderUtil: class PlanetShaderUtil
      constructor: (@innerRadius, @position) ->
        @nSamples = 3     # Number of sample rays to use in integral equation
        @Kr = 0.0025      # Rayleigh scattering constant
        @Km = 0.0015      # Mie scattering constant
        @ESun = 10.0      # Sun brightness constant
        @exposure = 2.0
        @wavelength = new THREE.Vector3(0.731, 0.612, 0.455)
        @G = -0.99
        @invWavelength4 = new THREE.Vector3()
        @scaleDepth = 0.25
        @rotationSpeed = 0.02
        @updateCalculations()

      updateCalculations: () =>
        @scale = 1.0 / ((@innerRadius * 1.025) - @innerRadius)
        @scaleOverScaleDepth = @scale / @scaleDepth
        @KrESun = @Kr * @ESun
        @KmESun = @Km * @ESun
        @Kr4PI = @Kr * 4.0 * Math.PI
        @Km4PI = @Km * 4.0 * Math.PI

        @invWavelength4.x = 1.0 / Math.pow(@wavelength.x, 4.0)
        @invWavelength4.y = 1.0 / Math.pow(@wavelength.y, 4.0)
        @invWavelength4.z = 1.0 / Math.pow(@wavelength.z, 4.0)

        @outerRadius = @innerRadius * 1.025

    Planet: class Planet extends THREE.Object3D
      constructor: (@radius, @pos, @sun, @camera) ->
        super

        @planetUtil = new ThreePlanet.objects.PlanetShaderUtil(@radius, @pos)

        # create 2 geometries since they will have different buffers
        details = 40
        #@sphere = new THREE.SphereGeometry( 1, details * 2 * 4, details * 4)
        @sphere = new THREE.SphereGeometry( 1, 256, 128)
        @sphere.computeTangents()
        @sphere2 = new THREE.SphereGeometry( 1, details * 2, details )

        @createBaseUniforms()

        #@mSkyFromSpace = new THREE.MeshPhongMaterial( { color: 0x00ff00 } )
        @createShaderSkyFromSpace()

        @createShaderSkyFromAtmosphere()
        @mSkyFromSpace.transparent = true
        @mSkyFromSpace.blending = THREE.AdditiveAlphaBlending
        @atmosphere = new THREE.Mesh( @sphere2, @mSkyFromSpace )
        @atmosphere.scale.set(@planetUtil.outerRadius, @planetUtil.outerRadius, @planetUtil.outerRadius)
        @atmosphere.flipSided = true
        #@add(@atmosphere)
        #return

        #@mGroundFromSpace = new THREE.MeshPhongMaterial( { color: 0xffffff, map: THREE.ImageUtils.loadTexture( 'textures/earth.jpg' ) } )
        @createShaderGroundFromSpace()

        @ground = new THREE.Mesh( @sphere, @mGroundFromSpace )
        @ground.scale.set(@planetUtil.innerRadius, @planetUtil.innerRadius, @planetUtil.innerRadius)
        @add(@ground)

        #@createClouds()
        return

      createClouds: () =>
        details = 42
        sphereClouds = new THREE.SphereGeometry( 1, details * 2, details )
        cloudsTexture = THREE.ImageUtils.loadTexture("textures/earth_clouds_1024.png")
        materialClouds = new THREE.MeshLambertMaterial( { color: 0xffffff, map: cloudsTexture, transparent:true, depthWrite: false } )
        @meshClouds = new THREE.Mesh( sphereClouds, materialClouds )
        cloudsRadius = @planetUtil.outerRadius - 2.0
        @meshClouds.scale.set(cloudsRadius, cloudsRadius, cloudsRadius)
        @meshClouds.doubleSided = false
        @add(@meshClouds)

      update: (time, delta) =>
        cameraLocation = @camera.position
        planetToCamera = cameraLocation.clone().subSelf(@pos)
        cameraHeight = planetToCamera.length()
        lightPosNormalized = @sun.position.clone().normalize()

        if @meshClouds
          @meshClouds.rotation.y = time * 0.002
        #console.log cameraHeight
        #console.log @planetUtil.outerRadius
        # easy collision detection
        #r = @planetUtil.innerRadius
        #if cameraHeight < r + 1.0
        #  @camera.position = planetToCamera.clone().normalize().multiplyScalar(r + 1.0)

        if cameraHeight > @planetUtil.outerRadius
          @atmosphere.material = @mSkyFromSpace
          #@atmosphere.material = @mSkyFromAtmosphere
        else
          @atmosphere.material = @mSkyFromAtmosphere
          #console.log "atmo"
        @mSkyFromSpace.uniforms.v3LightPos.value = lightPosNormalized
        @mSkyFromSpace.uniforms.fCameraHeight.value = cameraHeight
        @mSkyFromSpace.uniforms.fCameraHeight2.value = cameraHeight * cameraHeight
        @mSkyFromSpace.uniforms.v3InvWavelength.value = @planetUtil.invWavelength4

        @mSkyFromAtmosphere.uniforms.v3LightPos.value = lightPosNormalized
        @mSkyFromAtmosphere.uniforms.fCameraHeight.value = cameraHeight
        @mSkyFromAtmosphere.uniforms.fCameraHeight2.value = cameraHeight * cameraHeight
        @mSkyFromAtmosphere.uniforms.v3InvWavelength.value = @planetUtil.invWavelength4
        #@mSkyFromAtmosphere.uniforms.v3CameraPos.value = @camera.position
        #@mSkyFromSpace.uniforms.v3CameraPos.value = @camera.position

        if @mGroundFromSpace
          @mGroundFromSpace.uniforms.v3LightPos.value = lightPosNormalized
          @mGroundFromSpace.uniforms.Time.value = time
          @mGroundFromSpace.uniforms.fCameraHeight.value = cameraHeight
          @mGroundFromSpace.uniforms.fCameraHeight2.value = cameraHeight * cameraHeight
          #@mGroundFromSpace.uniforms.v3CameraPos.value = @camera.position

      createBaseUniforms: () =>
        @baseUniforms =
          Time:
            type: 'f'
            value: 0.0
          #v3CameraPos:
          #  type: 'v3'
          #  value: @camera.position
          fCameraHeight:
            type: 'f'
            value: 206.0
          fCameraHeight2:
            type: 'f'
            value: 32000.0
          v3LightPos:
            type: 'v3'
            value: @sun.position.clone().normalize()
          fg:
            type: 'f'
            value: @planetUtil.G
          fg2:
            type: 'f'
            value: @planetUtil.G * @planetUtil.G
          fExposure:
            type: 'f'
            value: @planetUtil.exposure
          fScaleDepth  :
            type: 'f'
            value: @planetUtil.scaleDepth
          fScaleOverScaleDepth:
            type: 'f'
            value: @planetUtil.scaleOverScaleDepth
          fSamples:
            type: 'f'
            value: @planetUtil.nSamples
          Speed:
            type: 'f'
            value: 0.005
          v3InvWavelength:
            type: 'v3'
            value: @planetUtil.invWavelength4
          fKrESun:
            type: 'f'
            value: @planetUtil.KrESun
          fKmESun:
            type: 'f'
            value: @planetUtil.KmESun
          fOuterRadius:
            type: 'f'
            value: @planetUtil.outerRadius
          fInnerRadius:
            type: 'f'
            value: @planetUtil.innerRadius
          fOuterRadius2:
            type: 'f'
            value: @planetUtil.outerRadius * @planetUtil.outerRadius
          fKr4PI:
            type: 'f'
            value: @planetUtil.Kr4PI
          fKm4PI:
            type: 'f'
            value: @planetUtil.Km4PI
          fScale:
            type: 'f'
            value: @planetUtil.scale

      createShaderSkyFromAtmosphere: () =>
        uniformsBase = THREE.UniformsUtils.clone(@baseUniforms)

        #$.extend(uniformsBase, uniformsSky)
        @mSkyFromAtmosphere = new THREE.ShaderMaterial
          uniforms: uniformsBase
          vertexShader: SkyFromAtmosphereVert
          fragmentShader: SkyFromAtmosphereFrag
          #depthWrite: false
          #shading: THREE.FlatShading

      createShaderSkyFromSpace: () =>
        uniformsBase = THREE.UniformsUtils.clone(@baseUniforms)

        #$.extend(uniformsBase, uniformsSky)
        @mSkyFromSpace = new THREE.ShaderMaterial
          uniforms: uniformsBase
          vertexShader: SkyFromSpaceVert
          fragmentShader: SkyFromSpaceFrag
          #depthWrite: false
          #shading: THREE.FlatShading

      createShaderGroundFromSpace: () =>
        planetTexture = THREE.ImageUtils.loadTexture("textures/earth_atmos_2048.jpg")
        nightTexture = THREE.ImageUtils.loadTexture("textures/earthnight.jpg")
        bumpTexture = THREE.ImageUtils.loadTexture("textures/earthbump.png")
        #@cloudsTexture = @planetTexture
        uniformsBase = THREE.UniformsUtils.clone(@baseUniforms)

        uniformsGround =
          tGround:
            type: 't'
            value: planetTexture
          tNight:
            type: 't'
            value: nightTexture
          tBump:
            type: 't'
            value: bumpTexture

        $.extend(uniformsBase, uniformsGround)
        #uniformsGround.v3CameraPos.value = @camera.position
        @mGroundFromSpace = new THREE.ShaderMaterial
          uniforms: uniformsBase
          vertexShader: GroundFromSpaceVert
          fragmentShader: GroundFromSpaceFrag


