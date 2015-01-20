%% [tSigV tSigM fSigM] = genOFDMsignal(varargin)
% This function generates an ACOOFDM or DCOOFDM or DMT signal. To generate
% real valued time domain signals, DMT is the same as DCO with 0 offset.
% 
% Note: For DCO/DMT, add sufficient offset to reduce negative clipping
%
% TODO: support for carrier prefix
% 
% VARIABLE INPUT ARGUMENTS: Listed below are optional input arguments that
% can be specified to modify the behaviour of the function.
%
% 1. DATA: A scalar argument is interpreted as length of data to transmit.
% A vector argument is interpreted as the vector containing the data to
% transmit. Each element of this vector must be an integral value in the
% range [1 M]; thus specifying 1 out of M possible QAM symbols for each
% subcarrier.
% (M is the number of elements in the 'Symbols' parameter and is 64 by
% default.)
%  default: A pseudo-random vector of data of length 1e6 is generated from
%  a uniform [1 M] distribution to assign to subcarriers.
% 
% 2. OFDMTYPE: Specifies ACOOFDM or DCOOFDM (DMT)
%  default: OFDMTYPE = DCOOFDM
% 
% 3. N: Specifies number of subcarriers for each OFDM symbol
%  default: N=64
% 
% 4. Symbols: Specifies symbols associated with data for each subcarrier
% 
% 5. SCALE: Specifies scale factor for time domain signal generated
%  default: SCALE = 1
% 
% 6. OFFSET: Specifies the offset for the scaled time domain signal
%  default: OFFSET = 0
% 
% 6.1 OFFSETDCOSTDDEV: Specifies the scale factor to multiply the standard
% deviation of each frame and add as an offset for DCO signals only.
%  default: OFFSETDCOSTDDEV = 2
% 
% 6.2 OFFSETACOSTDDEV: Specifies the scale factor to multiply the standard
% deviation of each frame and add as an offset for ACO signals only.
%  default: OFFSETACOSTDDEV = 0
% 
% 7. CLIPLOW: Specifies the lower clipping level for level shifted, scaled
% time domain signal
%  default: CLIPLOW = 0;
% 
% 8. CLIPHIGH: Specifies the upper clipping level for level shifted, scaled
% time domain signal
%  default: CLIPHIGH = maximum 'double' value (essentially no upper level
%  clipping)
% 
% 9. SEED: Specifies the seed for the pseudo-random data generation. This
% can help generate the same 'random' data for different iterations. Maybe
% useful for debugging system. If not specified, choice of seed is left to
% the MATLAB environment
% 
% 10. FILETYPE: Specifies the type of file to save time domain signal to.
% Accepted values are 'TEXT' or 'MAT'. If 'TEXT' is specified, the time
% domain signal is saved to a *.txt file. If 'MAT' is specified, the time
% domain signal is saved to a *.mat file that can be loaded again in
% MATLAB.
%  default: FILETYPE = 'TEXT'
% 
% 11. FILENAME: Specifies the name/path of the file to save time domain
% signal to.
%  default: FILENAME = 'signal.txt'
% 
% NOTE: If any one of FILETYPE OR FILENAME are specified, the function will
% always save the time domain signal to the file.
%
% NOTE: If both, FILETYPE AND FILENAME, are NOT specified, the function
% will save the time domain signal to file ONLY if zero (0) output
% arguments are expected to be returned.
%
% 12. SHOWCONST: Specifies the flag to show constellation (true/false)
%   default: false
% 
% OUTPUTS: 
% 1. TSIGV: time domain signal vector generated by the function.
% 
% 2. TSIGM: Matrix whose each column contains the time domain signal
% generated from each frequency domain OFDM symbol.
% 
% 3. FSIGM: Matrix whose each column contains the frequency domain OFDM
% symbols.
% 

%% HEADER -----------------------------------------------------------------
% Author: Pankil Butala
% Email: pbutala@bu.edu 
% Institution: Multimedia Communications Laboratory,
%              Boston University.
% Generated: 14th February, 2013
% Modifications: 
% 02/15/13: tSigM = ifft(fSigM,N,1)*sqrt(N) ;
%           Scaled ifft with sqrt(N) to preserve energy.
% 08/15/13: Replaced input argument 'M' with Symbols to accomodate
%           different subcarrier modulation types.
%           Added support for DMT (same as DCO with 0 offset)
% 08/16/13: Added support for adding offset based on standard deviation for
%           signals generated by DCOOFDM
% 10/15/13: Added support for adding offset based on standard deviation for
%           signals generated by ACOOFDM
% 04/14/14: Added support to show constellation symbols
%
% Disclaimer: The file is provided 'as-is' to the user. It has not been
% tested for any bugs or inconsistent behavior. If you have any questions
% or bugs to report, please email the author at the specified email address
%
% Copyright (C) Pankil Butala 2013
% End Header --------------------------------------------------------------

function [tSigV,tSigM,fSigM] = genOFDMsignal(varargin)
%% default initialization 
%(DO NOT MODIFY) Any changes in default behavior must be addressed using
%the variable input arguments.
dataLen = 1e6;              % default data length
ofdmType = 'DCOOFDM';       % default OFDM type
N = 64;                     % default # subcarriers
M = 64;                     % default # QAM symbols per subcarrier
SymSC = getQAMsyms(M);      % default constellation
fileType = 'text';          % default file type to save time domain signal to
fileName = 'signal.txt';    % default file to save time domain signal to
scale = 1;                  % default scale for time domain signal
offset = 0;                 % default offset for time domain signal
ofstSDsclDco = 2;           % default offset for DCO. scale the Std Dev by this factor
ofstSDsclAco = 0;           % default offset for DCO. scale the Std Dev by this factor
clipLow = 0;                % default LOW clip value for time domain signal
clipHigh = realmax('double');   % default HIGH clip value for time domain signal
fShowConst = false;         % default flag for showing constellations generated by data

% end default initialization-----------------------------------------------

%% Read input parameters, if specified
nVArg = nargin;
if (rem(nVArg,2)~= 0)
    error('Check input arguments');
end
ArgName = 1;
ArgParam = ArgName + 1;
while(ArgName < nVArg)
    switch lower(varargin{ArgName})
        case 'data'
            if isscalar(varargin{ArgParam})
                dataLen = varargin{ArgParam};
            elseif isvector(varargin{ArgParam})
                data = varargin{ArgParam};
            else
                error('''data'' must be a scalar or a vector.');
            end
        case 'ofdmtype'
            ofdmType = varargin{ArgParam};
        case 'n'
            N = varargin{ArgParam};
        case 'symbols'
            SymSC = varargin{ArgParam};
            if isvector(SymSC)
                M = numel(SymSC);
            else
                error('''Symbols'' must be a vector');
            end
            if (rem(log2(M),1) ~= 0)||(M==0)
                warning('Number of symbols is not an integral exponent of 2');
            end
        case 'scale'
            scale = varargin{ArgParam};
        case 'offset'
            offset = varargin{ArgParam};
        case 'offsetdcostddev'
            ofstSDsclDco = varargin{ArgParam};
        case 'offsetacostddev'
            ofstSDsclAco = varargin{ArgParam};
        case 'cliplow'
            clipLow = varargin{ArgParam};
        case 'cliphigh'
            clipHigh = varargin{ArgParam};
        case 'seed'
            seed = varargin{ArgParam};
        case 'filetype'
            fileType = varargin{ArgParam};
            switch lower(fileType)
                case {'text','mat'}
                    %do nothing
                otherwise
                    error('File type must be ''TEXT'' or ''MAT''');
            end
            fSave = true;
        case 'filename'
            fileName = varargin{ArgParam};
            fSave = true;
        case 'showconst'
            bflg = varargin{ArgParam};
            if isa(bflg,'logical')
                fShowConst = bflg;
            else
                error('ShowConst must be logical');
            end
        otherwise
            error('unknown parameter %s specified',varargin{ArgName});
    end
    ArgName = ArgName + 2;
    ArgParam = ArgName + 1;
end

%% Generate Data
if exist('data','var')
    dataLen = numel(data);  % if data provided, calculate its length
else
    if exist('seed','var')
        rng(seed);  % if seed specified, initialize RNG with seed.
    end
    data = randi(M,[dataLen 1]); % if data not provided, randomly generate data
end

%% Calculate number of data bearing carriers for specified ofdm type
switch lower(ofdmType)
    case 'acoofdm'
        d = N/4;    % number of data carriers per ACOOFDM symbol
        fHop = 2;
    case {'dcoofdm','dmt'}
        d = N/2 - 1;    % number of data carriers per DCOOFDM symbol
        fHop = 1;
    otherwise
        error('OFDM type must be ''ACOOFDM'' or ''DCOOFDM'' or ''DMT''');
end

%% Generate constellation
% SymSC = zeros(M+1,1);       % M+1st constellation point is set to 0 to assign it to padded data
SymSC = [SymSC(:);0];
% SymSC(1:M) = getQAMsyms(M); % Get subcarrier symbols

%% Zero Pad the data signal 
% Ensures that all data bearing ofdm symbol carriers have a value associated with them
padLen = rem(dataLen,d);
if padLen ~= 0
    padLen = d-rem(dataLen,d);
end
pData = [data(:);(M+1)*ones(padLen,1)]; % vector to store padded data
dataLen = numel(pData);             % calculate new data length                          
Nsym = dataLen/d;                   % calculate number of ofdm symbols to generate
mData = reshape(pData,d,Nsym);      % mData stores padded data. each column has data associated with that ofdm symbol.

%% Create Symbols
fSigM = zeros(N,Nsym);               % create buffer for signal
fSigM(2:fHop:N/2,:) = SymSC(mData);  % assign symbols to bottom half subcarriers
fSigM(N/2+2:fHop:end,:) = conj(SymSC(mData(end:-1:1,:))); % impose hermetian symmetry through each column

%% Create time domain signal
tSigM = ifft(fSigM,N,1)*sqrt(N);      % IFFT to generate time domain signal
tSigM = tSigM.*scale;                 % Scale
stdDevs = std(tSigM,0,1);           % calculate Std Devs for all frames
if strcmpi(ofdmType,'dcoofdm')          % if DCO
    tSigM = tSigM + ofstSDsclDco.*repmat(stdDevs,N,1);  % add DCO offset
end
tSigM = tSigM + offset;               % Offset
tSigM(tSigM < clipLow) = clipLow;     % Clip Low
tSigM(tSigM > clipHigh) = clipHigh;   % Clip High
if strcmpi(ofdmType,'acoofdm')          % if ACO
    tSigM = tSigM + ofstSDsclAco.*repmat(stdDevs,N,1);  % add ACO offset
end
% PavgSym = sum(tSigM.*tSigM,1);  % calculate average power per symbol
% NormSym = repmat(sqrt(PavgSym),[N,1]);        % Calculate normalization const for each symbol
% tSigM = tSigM./NormSym;   % Normalize for average power per symbol = 1

tSigV = tSigM(:);                    % Create a time series vector for the signal

%% show constellation
if fShowConst
    Re = real(SymSC(data));     % Get real parts of data symbols
    Im = imag(SymSC(data));     % Get imag parts of data symbols
    uRe = unique(Re);           % Unique, sorted Scaled Real constellation values
    uIm = unique(Im);           % Unique, sorted Scaled Imag constellation values
    dRe = abs(uRe(1) - uRe(2)); % Distance between adjascent Re values
    dIm = abs(uIm(1) - uIm(2)); % Distance between adjascent Im values
    figure;                     % Generate axes for scatterplot
    scatter(Re,Im,72,'bx');             % Display the constellation on current axes
    set(gca,'XTick',uRe);       % Set X tick values to indicate Re coeffs
    set(gca,'YTick',uIm);       % Set Y tick values to indicate Im coeffs
    grid on;                    % Show the grid
    axis([uRe(1)-dRe uRe(end)+dRe uIm(1)-dIm uIm(end)+dIm]); % Scale axes for pleasant display
    axis equal;                 % Set axis aspect ratio = 1
    xlabel('Real');             % X axis shows Re constellation values
    ylabel('Imag');             % Y axis shoes Im constellation values
    tStr = sprintf('%d-QAM constellation diagram',M);   % Generate title
    title(tStr);                % Show title
end
%% Save data to file
% if save option NOT specified, save to file ONLY if time domain signal is
% NOT returned to caller
if ~exist('fSave','var')
    fSave = (nargout == 0);
end
if fSave
    switch lower(fileType)
        case 'text'
            fid = fopen(fileName,'w');  % open file to write to
            if fid~= -1
                fprintf(fid,'%f\r\n',tSigV);
                fclose(fid);
            else
                error('Error opening ''%s'' file.\n',fileName);
            end
        case 'mat'
            save filePath tSigV;        % save to signal file
        otherwise
            error('File type must be ''TEXT'' or ''MAT''');
    end
end
end % end genOFDMsignal