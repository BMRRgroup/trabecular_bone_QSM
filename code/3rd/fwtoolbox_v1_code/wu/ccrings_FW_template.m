% Project: Concentric Rings Fat/Water Imaging
% Filename: ccrings_FW_template.m
%   Template for concentric rings fat/water separation using
%   k-space freq demodulation and any general image-space algorithm.
%
%   See ccrings_FW_gcut.m for an example.
%
%   Please consult the README file for more information.
% 
% Modified:
%
% Last Modified: 2012/01/16
% Created:       2012/01/16
% Holden H. Wu
% holdenhwu@stanford.edu

clear all; % close all;

fprintf(1, '\nStarting ccrings_FW_templ ---------------------------- \n');

% Set paths
% ========================================================================
% Concentric rings
CCR_PATH = './';
% path for support functions
CCR_PATH_LIB  = [CCR_PATH 'ccrlib/'];
CCR_PATH_GRID = [CCR_PATH 'grid2D/'];
addpath( CCR_PATH_LIB );
addpath( CCR_PATH_GRID );
% path for loading data
CCR_PATH_DATA = [CCR_PATH 'ccrdata/'];

% Paths for the desired image-space algorithm
% ...
% ...
% ========================================================================

% Flags
% ========================================================================
% Recon settings
PHset     = -1; % phases to include in recon, -1 for all
SLset     = -1; % slices to include in recon, -1 for all
CHset     = -1; % channels to include in recon, -1 for all

% Plot settings
PLOT_IMGS = 1; % plot final water, fat, water+fat images
CONST_WND = 1; % whether to use the same window/level for each slice

% Output settings
WRITE_CINE= 0; % save recon as an .avi movie
SAVE_RECON= 0; % save recon as a .mat file 
% ========================================================================

% Specify concentric rings dataset and algoParams
DATASET = 2;
% ========================================================================
if( DATASET==1 )
  % 2009, 05/20: 8-ch array, subject
  % 3D stack-of-rings head scan, 3 of 180 1-mm slices
  % already Fourier-transformed in the slice direction
  % slice 3 is the most interesting
  % (cf. Wu et al., MRM 2010;63:1210-1218)
  MFile = '20090520_3DHeadB_3sl';
  CHset=[-1]; PHset=[1]; SLset=[3];
  algoParams.cFOV=1; 
  algoParams.imrot=0;   
elseif( DATASET==2 )
  % 2011, 08/19: 8-ch array, subject
  % 2D short axis cardiac cine, 18 phases
  % channels 7,8 are too noisy, so omit from recon
  % (cf. Wu et al., ISMRM 2011, p.4366)
  MFile = '20110819_SAX'; 
  CHset=[1,2,3,4,5,6]; PHset=[1]; SLset=[1];
  algoParams.cFOV=1; 
  algoParams.imrot=0;   
elseif( DATASET==3 )  
  % 2011, 08/19: 8-ch array, subject
  % 2D long axis cardiac cine, 18 phases
  % channels 2,6 are too noisy, so omit from recon
  % (cf. Wu et al., ISMRM 2011, p.4366)
  MFile = '20110819_LAX'; 
  CHset=[1,3,4,5,7,8]; PHset=[1]; SLset=[1];
  algoParams.cFOV=1; 
  algoParams.imrot=0;   
else
  fprintf(1, 'Error: DATASET %d does not exist.\n', DATASET);
  return;
end
% ========================================================================

% Load the specified .mat file 
% ========================================================================
% load 'kDataParams'
load( sprintf('%s/%s.mat', CCR_PATH_DATA,MFile) );
fprintf(1, 'Done loading %s/%s.mat\n', CCR_PATH_DATA,MFile);

% Specify phases to reconstruct
recon_ph = getsubset(PHset, 1, kDataParams.Nph);
% Specify slices to reconstruct
recon_sl = getsubset(SLset, 1, kDataParams.Nsl);
% Specify channels to reconstruct
recon_ch = getsubset(CHset, 1, kDataParams.Nch);
fprintf(1, 'Extracting %d/%d ph, %d/%d sl, %d/%d ch for recon.\n', ...
numel(recon_ph),kDataParams.Nph,numel(recon_sl),kDataParams.Nsl,numel(recon_ch),kDataParams.Nch);
% Extract subset of raw k-space data
% kdata is [rdout, view, phase, slice, channel]
kDataParams.kdata = kDataParams.kdata(:,:,recon_ph,recon_sl,recon_ch);
kDataParams.Nph = size( kDataParams.kdata, 3 );
kDataParams.Nsl = size( kDataParams.kdata, 4 );
kDataParams.Nch = size( kDataParams.kdata, 5 );
% ========================================================================

% Based on the field map obtained from the image-space algorithm,
% the rings k-space data is demodulated at fat frequency and input to
% a modified least-squares algorithm to obtain unblurred fat.
%
% Set params for frequency-demodulated least squares estimation
% (a modified version of IDEAL)
% ========================================================================
GAM = 42.576*1e6; % Hz/Tesla, for protons
algoParams.df_FW = -3.5*1e-6 * GAM * kDataParams.B0; % -3.5 ppm -> Hz
algoParams.f0    = 0;
algoParams.TEs   = [];
% Whether to impose circular FOV
zpadX = 1; % zero-interpolate the images zpadX-fold
algoParams.padN = zpadX * kDataParams.imgN;
if( algoParams.cFOV )
    xaxis = -algoParams.padN/2:(algoParams.padN/2-1);
    [X, Y] = meshgrid( xaxis, xaxis );
    R = sqrt( X.^2 + Y.^2 );
    algoParams.rMask = zeros(algoParams.padN, algoParams.padN);
    algoParams.rMask( R < algoParams.padN/2 ) = 1;
    % figure; imagesc(algoParams.rMask); colormap gray; axis image; truesize;
else
    algoParams.rMask = ones(algoParams.padN, algoParams.padN);
end
% ========================================================================

% Set parameters for the desired image-space algorithm
% ========================================================================
% ...
% ...
% ========================================================================

% Now perform fat/water recon!
% type 'help fw_tttttt_ccr_imsp_wu' for more information
% see fw_k2cs1i_ccr_gcut_wu for an example
tt0 = cputime;
% ========================================================================
outParams = fw_tttttt_ccr_imsp_wu( kDataParams, imspParams, algoParams );
% ========================================================================
tt = cputime-tt0;
fprintf(1, 'Recon time: %.2f sec\n', tt);

% Combine multiple channels, rSOS for now
% ========================================================================
imgWSOS = zeros( algoParams.padN, algoParams.padN, kDataParams.Nph, kDataParams.Nsl );
imgFSOS = zeros( algoParams.padN, algoParams.padN, kDataParams.Nph, kDataParams.Nsl );
for sl=1:kDataParams.Nsl,
  for ph=1:kDataParams.Nph,
    imgWSOS(:,:,ph,sl) = sqrt( sum( abs(outParams.species(1).amps(:, :, ph,sl,:)).^2, 5 ) );
    imgFSOS(:,:,ph,sl) = sqrt( sum( abs(outParams.species(2).amps(:, :, ph,sl,:)).^2, 5 ) );
  end
end
% ========================================================================
fprintf(1, 'Done combining coils (root of sum of squares).\n');


if( PLOT_IMGS )
% ========================================================================    
wnd = [];
if( CONST_WND>0 )
    w_max = max( abs([imgWSOS(:); imgFSOS(:)]) );
    w_min = min( abs([imgWSOS(:); imgFSOS(:)]) );
    wnd = [w_min, CONST_WND*w_max];
end

if( kDataParams.Nph>4 )
    rpt = 4; tfr = 0.1;
else
    rpt = 1; tfr = 0.5;
end    

% Plot results
for sl=1:kDataParams.Nsl,
  for rr=1:rpt,
    for ph=1:kDataParams.Nph,
    imgPlotW = reshape( imgWSOS(:, :, ph,sl), algoParams.padN,algoParams.padN );
    imgPlotF = reshape( imgFSOS(:, :, ph,sl), algoParams.padN,algoParams.padN );
    imgPlotWF = sqrt(imgPlotW.^2+imgPlotF.^2);
    
    figure(111); 
    if( CONST_WND>0 )
        imagesc( [abs(imgPlotW) abs(imgPlotF) imgPlotWF], wnd ); 
    else
        imagesc( [abs(imgPlotW) abs(imgPlotF) imgPlotWF] );
    end    
    colormap gray; axis image; truesize; 
    title(sprintf('Water | Fat | Combined, sl%d/%d, ph%d/%d', ...
                  sl,kDataParams.Nsl,ph,kDataParams.Nph));
    pause(tfr);
    end
  end
  pause(1);
end

% Plot fMap
for sl=1:kDataParams.Nsl,
  for rr=1:rpt,    
    for ph=1:kDataParams.Nph,
    figure(211);    
    imagesc( outParams.fMap(:,:,ph,sl) ); colormap gray; axis image; truesize;
    title(sprintf('Field map (Nch=%d), sl%d/%d, ph%d/%d', ...
          kDataParams.Nch,sl,kDataParams.Nsl,ph,kDataParams.Nph));
    pause(tfr);
    end
  end
  pause(1);
end

% Plot R2* map
if( gcutParams.NUM_R2STARS>1 )
% ------------------------------------------------------------------------
for sl=1:kDataParams.Nsl,
  for rr=1:rpt,    
    for ph=1:kDataParams.Nph,
    figure(311);    
    imagesc( outParams.r2star(:,:,ph,sl) ); colormap gray; axis image; truesize;
    title(sprintf('R2* map (Nch=%d), sl%d/%d, ph%d/%d', ...
          kDataParams.Nch,sl,kDataParams.Nsl,ph,kDataParams.Nph));
    pause(tfr);
    end
  end
  pause(1);
end
% ------------------------------------------------------------------------
end
% ========================================================================
end % PLOT_IMGS

% Assumes img is [N N Nph] and only 1 slice for now
if( WRITE_CINE && kDataParams.Nph>1 )
% ========================================================================
    SAVE_DIR = sprintf('%s/%s_FW/', CCR_PATH,MFile);
    if( ~exist(SAVE_DIR, 'dir') )
        mkdir( SAVE_DIR );
    end
    
    movfname = sprintf('%s/%s_cine.avi', SAVE_DIR,MFile);
    fps = ccr_savecine([imgWSOS imgFSOS sqrt(imgWSOS.^2+imgFSOS.^2)], movfname, 1.0, 0, 'None');
    
    fprintf(1, 'Finished WRITE_CINE to %s\n', movfname);    
% ========================================================================
end

% Output recon results in a .mat file
if( SAVE_RECON )
% ========================================================================    
    SAVE_DIR = sprintf('%s/%s_FW/', CCR_PATH,MFile);
    if( ~exist(SAVE_DIR, 'dir') )
        mkdir( SAVE_DIR );
    end
    
    filename = sprintf( '%s/%s.mat', SAVE_DIR,MFile );
    save(filename, '-mat', 'outParams', 'PHset','SLset','CHset' );
    
    fprintf(1, 'Finished SAVE_RECON to %s\n', filename);    
% ========================================================================    
end

fprintf(1, '---------------------------- Finished ccrings_FW_templ \n');
