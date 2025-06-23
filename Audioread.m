clear all
close all
% Fs=44100;
path='C:\Books\ECE-414\FinalProject'

%  femalefile=strcat(path,'\femaleSpeech.m4a');
%  [female,Fs] = audioread(femalefile);
%  % sound(female,Fs)
% 
% malefile=strcat(path,'\maleSpeech.m4a');
% [male,Fs] = audioread(malefile);
% % sound(male,Fs)
% save  femaleSpeechmat female Fs
% save  maleSpeechmat male  Fs

 femalefile=strcat(path,'\KDH_Speech.m4a');
 [female,Fs] = audioread(femalefile);
 % sound(female,Fs)

malefile=strcat(path,'\DJT_Speech.m4a');
[male,Fs] = audioread(malefile);
% sound(male,Fs)
save('C:\Books\ECE-414\FinalProject\femaleSpeechmat02.mat', 'female', 'Fs');
save('C:\Books\ECE-414\FinalProject\maleSpeechmat02.mat', 'male', 'Fs');
