close all
clear all
% [femaleSpeechTrain,Fs] = audioread('C:\Liev\temp\femaleSpeech.m4a');
% femaleSpeechTrain=resample(femaleSpeechTrain,4000,48000);
% femaleSpeechTrain=femaleSpeechTrain(:,1);
% save C:\Liev\temp\femaleSpeech  femaleSpeechTrain
% [maleSpeechTrain,Fs] = audioread('C:\Liev\temp\maleSpeech.m4a');
% maleSpeechTrain=resample(maleSpeechTrain,4000,48000);
% maleSpeechTrain=maleSpeechTrain(:,1);
% save C:\Liev\temp\maleSpeech  maleSpeechTrain

%加载音频文件，其中包含以 4 kHz 采样的男性和女性语音。单独收听音频文件以供参考。
% Fs_sound = 44100;
path='C:\Books\ECE-414\FinalProject'
femalemat=strcat(path,'\femaleSpeechmat02.mat');

load (femalemat);
malemat=strcat(path,'\maleSpeechmat02.mat');
load (malemat);
femaleSpeech = female(:,1);
maleSpeech = male(:,1);
Fs_sound = Fs;

femaleSpeechTrain = femaleSpeech(1:2200000);femaleSpeechValidate = femaleSpeech(2200000:2646000);
maleSpeechTrain = maleSpeech(1:2200000);maleSpeechValidate = maleSpeech(2200000:2646000);

L = min(length(maleSpeechTrain),length(femaleSpeechTrain));  
maleSpeechTrain   = maleSpeechTrain(1:L);
femaleSpeechTrain = femaleSpeechTrain(1:L);


L = min(length(maleSpeechValidate),length(femaleSpeechValidate));  
maleSpeechValidate   = maleSpeechValidate(1:L);
femaleSpeechValidate = femaleSpeechValidate(1:L);
% figure(1)
% subplot(211);plot(L/Fs,femaleSpeechTrain);xlable('s');title('femaleSpeech')
% subolot(212);plot(L/Fs,maleSpeechTrain);xlable('s');title('maleSpeech')


% Scale the training signals to the same power level. Scale the validation signals to the same power level.
maleSpeechTrain   = maleSpeechTrain/norm(maleSpeechTrain);
femaleSpeechTrain = femaleSpeechTrain/norm(femaleSpeechTrain);
ampAdj            = max(abs([maleSpeechTrain;femaleSpeechTrain]));
maleSpeechTrain   = maleSpeechTrain/ampAdj;
femaleSpeechTrain = femaleSpeechTrain/ampAdj;

maleSpeechValidate   = maleSpeechValidate/norm(maleSpeechValidate);
femaleSpeechValidate = femaleSpeechValidate/norm(femaleSpeechValidate);
ampAdj               = max(abs([maleSpeechValidate;femaleSpeechValidate]));
maleSpeechValidate   = maleSpeechValidate/ampAdj;
femaleSpeechValidate = femaleSpeechValidate/ampAdj;

%Create a cocktail party mixing model for the training and validation signals.
mixTrain = maleSpeechTrain + femaleSpeechTrain;
mixTrain = mixTrain / max(mixTrain);

mixValidate = maleSpeechValidate + femaleSpeechValidate;
mixValidate = mixValidate / max(mixValidate);

% STFT
%Select the Hanning window as the window function (length of 128, periodic), 
% with an FFT (Fast Fourier Transform) length of 128 and an overlap length of 127 (conjugate symmetric).
WindowLength  = 128;
FFTLength     = 128;
OverlapLength = 128-1;
Fs            = 48000;
win           = hann(WindowLength,"periodic");

P_mix0 = stft(mixTrain,'Window',win,'OverlapLength',OverlapLength,'FFTLength',FFTLength);
P_M    = abs(stft(maleSpeechTrain,'Window',win,'OverlapLength',OverlapLength,'FFTLength',FFTLength));
P_F    = abs(stft(femaleSpeechTrain,'Window',win,'OverlapLength',OverlapLength,'FFTLength',FFTLength));

% Reduce the obtained STFT to half of its original length.
N      = 1 + FFTLength/2;
P_mix0 = P_mix0(N-1:end,:);
P_M    = P_M(N-1:end,:);
P_F    = P_F(N-1:end,:);

%Take the logarithm of the mixed STFT. Normalize these values using the mean and standard deviation.
P_mix = log(abs(P_mix0) + eps);
MP    = mean(P_mix(:));
SP    = std(P_mix(:));
P_mix = (P_mix - MP) / SP;

%Do with Validation date 
P_Val_mix0 = stft(mixValidate,'Window',win,'OverlapLength',OverlapLength,'FFTLength',FFTLength);
P_Val_M    = abs(stft(maleSpeechValidate,'Window',win,'OverlapLength',OverlapLength,'FFTLength',FFTLength));
P_Val_F    = abs(stft(femaleSpeechValidate,'Window',win,'OverlapLength',OverlapLength,'FFTLength',FFTLength));

P_Val_mix0 = P_Val_mix0(N-1:end,:);
P_Val_M    = P_Val_M(N-1:end,:);
P_Val_F    = P_Val_F(N-1:end,:);

P_Val_mix = log(abs(P_Val_mix0) + eps);
MP        = mean(P_Val_mix(:));
SP        = std(P_Val_mix(:));
P_Val_mix = (P_Val_mix - MP) / SP;

%Check whether the data distribution is smooth by plotting a histogram of the STFT values for the training data.
figure(6)
histogram(P_mix,"EdgeColor","none","Normalization","pdf")
xlabel("Input Value")
ylabel("Probability Density")

% Compute the training soft mask. Use this mask as the target signal during network training.
maskTrain    = P_M ./ (P_M + P_F + eps);

% compute the validation soft mask. Use this mask to evaluate the mask generated by the network trained on the training data.
maskValidate = P_Val_M ./ (P_Val_M + P_Val_F + eps);

%Check whether the target distribution is smooth. Please draw a histogram of the data values.
figure(7)
histogram(maskTrain,"EdgeColor","none","Normalization","pdf")
xlabel("Input Value")
ylabel("Probability Density")

%Divide the training data and target mask into small blocks of size (65, 20).
% To obtain more diverse training samples, use 10 samples as overlap between consecutive blocks.
seqLen        = 20;
seqOverlap    = 10;
mixSequences  = zeros(1 + FFTLength/2,seqLen,1,0);
maskSequences = zeros(1 + FFTLength/2,seqLen,1,0);

loc = 1;
while loc < size(P_mix,2) - seqLen
    mixSequences(:,:,:,end+1)  = P_mix(:,loc:loc+seqLen-1); %#ok
    maskSequences(:,:,:,end+1) = maskTrain(:,loc:loc+seqLen-1); %#ok
    loc                        = loc + seqOverlap;
end

%Divide the validation data and target mask into small blocks of size (65, 20). 

mixValSequences  = zeros(1 + FFTLength/2,seqLen,1,0);
maskValSequences = zeros(1 + FFTLength/2,seqLen,1,0);
seqOverlap       = seqLen;

loc = 1;
while loc < size(P_Val_mix,2) - seqLen
    mixValSequences(:,:,:,end+1)  = P_Val_mix(:,loc:loc+seqLen-1); %#ok
    maskValSequences(:,:,:,end+1) = maskValidate(:,loc:loc+seqLen-1); %#ok
    loc                           = loc + seqOverlap;
end


% Reshape the training and validation data.
mixSequencesT  = reshape(mixSequences,    [1 1 (1 + FFTLength/2) * seqLen size(mixSequences,4)]);
mixSequencesV  = reshape(mixValSequences, [1 1 (1 + FFTLength/2) * seqLen size(mixValSequences,4)]);
maskSequencesT = reshape(maskSequences,   [1 1 (1 + FFTLength/2) * seqLen size(maskSequences,4)]);
maskSequencesV = reshape(maskValSequences,[1 1 (1 + FFTLength/2) * seqLen size(maskValSequences,4)]);

% Define the layers of the network. Specify the input 
% size as an image of size 1×1×1300. Define two hidden fully connected layers, each with 1300 neurons.
% Each hidden fully connected layer is followed by a ReLu layer.

% A batch normalization layer is added to normalize the mean and standard deviation 
% of the output. Add a fully connected layer with 1300 neurons, followed by a regression layer.
numNodes = (1 + FFTLength/2) * seqLen;

layers = [ ...
    
    imageInputLayer([1 1 (1 + FFTLength/2)*seqLen],"Normalization","None")
    
    fullyConnectedLayer(numNodes)
%     BiasedSigmoidLayer(6)
     reluLayer()
    batchNormalizationLayer
    dropoutLayer(0.1)

    fullyConnectedLayer(numNodes)
  %  BiasedSigmoidLayer(6)
    reluLayer()
    batchNormalizationLayer
    dropoutLayer(0.1)

 
    
    fullyConnectedLayer(numNodes)
    %BiasedSigmoidLayer(0)
    reluLayer()

    regressionLayer
    
    ];
% % Specify the training options for the network.
% Set MaxEpochs to 3 to train the network for 3 epochs based on the training data.
% Set MiniBatchSize to 64 so the network can process 64 training signals at a time.
% % Set Plots to training-progress to generate a plot showing how training progress changes with the number of iterations.
% Set Verbose to false to suppress printing table outputs corresponding to the data shown in the plot in the Command Window.
% Set Shuffle to every-epoch to shuffle the training sequences at the start of each epoch.
% Set LearnRateSchedule to piecewise so that the learning rate decreases by a specified factor (0.1) after a certain number of epochs (1).
% Set ValidationData to the validation predictors and targets.
% Set ValidationFrequency to compute the validation mean squared error once per epoch.
% This example uses the Adaptive Moment Estimation (ADAM) solver.

maxEpochs     = 3;
miniBatchSize = 64;

options = trainingOptions("adam", ...
    "MaxEpochs",maxEpochs, ...
    "MiniBatchSize",miniBatchSize, ...
    "SequenceLength","longest", ...
    "Shuffle","every-epoch",...
    "Verbose",0, ...
    "Plots","training-progress",...
    "ValidationFrequency",floor(size(mixSequencesT,4)/miniBatchSize),...
    "ValidationData",{mixSequencesV,maskSequencesV},...
    "LearnRateSchedule","piecewise",...
    "LearnRateDropFactor",0.9, ...
    "LearnRateDropPeriod",1);
% Train the deep learning network
% Use trainNetwork to train the network with the specified training options. 
% Since the training set is large, the training process may take several minutes. 
% To load a pre-trained network, set doTraining to false.
doTraining = true;
if doTraining
    CocktailPartyNet = trainNetwork(mixSequencesT,maskSequencesT,layers,options);
else
    s = load("CocktailPartyNet.mat");
    CocktailPartyNet = s.CocktailPartyNet;
end

% Pass the validation predictors to the trained network.
% The output is the estimated mask. Reshape the estimated mask to its original shape.
estimatedMasks0 = predict(CocktailPartyNet,mixSequencesV);

estimatedMasks0 = estimatedMasks0.';
estimatedMasks0 = reshape(estimatedMasks0,1 + FFTLength/2,numel(estimatedMasks0)/(1 + FFTLength/2));

% Evaluate the deep learning network
% Draw a histogram of the difference between the validation masks and the estimated masks.
figure(8)
histogram(maskValSequences(:) - estimatedMasks0(:),"EdgeColor","none","Normalization","pdf")
xlabel("Mask Error")
ylabel("Probability Density")

% Evaluate the mask estimation
% Estimate the binary masks for male and female voices using the soft masks.
SoftMaleMask   = estimatedMasks0; 
SoftFemaleMask = 1 - SoftMaleMask;

% 缩短混音 STFT 以匹配估计的掩膜的大小。
P_Val_mix0 = P_Val_mix0(:,1:size(SoftMaleMask,2));
% 将混音 STFT 乘以男声软掩膜，得到估计的男性语音 STFT。
P_Female = P_Val_mix0 .* SoftMaleMask;
% 将单侧 STFT 转换为居中 STFT。
P_Female = [conj(P_Female(end-1:-1:2,:)) ; P_Female ];
% Use ISTFT to obtain the estimated male speech signal. Normalize the signal.。
maleSpeech_est_soft = istft(P_Female, 'Window',win,'OverlapLength',OverlapLength,'FFTLength',FFTLength,'ConjugateSymmetric',true);
maleSpeech_est_soft = maleSpeech_est_soft / max(abs(maleSpeech_est_soft));
% Visualize the soft-masked estimated male speech and the original male speech. 
% Focus on the range of the soft-masked estimated male speech signal.
range = (numel(win):numel(maleSpeech_est_soft)-numel(win));
t     = range * (1/Fs);

figure(9)
subplot(2,1,1)
plot(t,maleSpeechValidate(range))
title("Original Male Speech")
xlabel("Time (s)")
grid on
subplot(2,1,2)
plot(t,maleSpeech_est_soft(range))
xlabel("Time (s)")
title("Estimated Male Speech (Soft Mask)")
grid on

% Multiply the mixed STFT with the binary soft female mask to get the estimated female speech STFT. 
% Use ISTFT to obtain the estimated female speech signal. Normalize the signal.
P_Female = P_Val_mix0 .* SoftFemaleMask;

P_Female = [conj(P_Female(end-1:-1:2,:)) ; P_Female];

femaleSpeech_est_soft = istft(P_Female,'Window',win,'OverlapLength',OverlapLength,'FFTLength',FFTLength,'ConjugateSymmetric',true);
femaleSpeech_est_soft = femaleSpeech_est_soft / max(femaleSpeech_est_soft);
% Focus on the range of the soft-masked estimated female speech signal.
range = (numel(win):numel(femaleSpeech_est_soft) - numel(win));
range = (numel(win):numel(femaleSpeech_est_soft) - numel(win));
t     = range * (1/Fs);
% t=(1:length(femaleSpeechValidate))/Fs_sound;
figure(10)
subplot(2,1,1)
plot(t,femaleSpeechValidate(range))
title("Original Female Speech")
grid on

% t=(1:length(femaleSpeech_est_soft))/Fs_sound;
subplot(2,1,2)
plot(t,femaleSpeech_est_soft(range))
xlabel("Time (s)")
title("Estimated Female Speech (Soft Mask)")
grid on