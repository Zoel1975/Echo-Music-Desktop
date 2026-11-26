// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  /// Fallback used by widget tests and any surface built before the delegate
  /// loads. `Intl.message` returns its source string without a loaded locale,
  /// so this is safe and keeps callers from asserting in isolation.
  static final S _fallback = S();

  static S get current => _current ?? _fallback;

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) =>
      S.maybeOf(context) ?? _current ?? _fallback;

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Echo`
  String get Echo {
    return Intl.message('Echo', name: 'Echo', desc: '', args: []);
  }

  /// `Next Up`
  String get Next_Up {
    return Intl.message('Next Up', name: 'Next_Up', desc: '', args: []);
  }

  /// `Shuffle`
  String get Shuffle {
    return Intl.message('Shuffle', name: 'Shuffle', desc: '', args: []);
  }

  /// `Home`
  String get Home {
    return Intl.message('Home', name: 'Home', desc: '', args: []);
  }

  /// `Saved`
  String get Saved {
    return Intl.message('Saved', name: 'Saved', desc: '', args: []);
  }

  /// `YTMusic`
  String get YTMusic {
    return Intl.message('YTMusic', name: 'YTMusic', desc: '', args: []);
  }

  /// `Settings`
  String get Settings {
    return Intl.message('Settings', name: 'Settings', desc: '', args: []);
  }

  /// `Search Echo`
  String get Search_Echo {
    return Intl.message(
      'Search Echo',
      name: 'Search_Echo',
      desc: '',
      args: [],
    );
  }

  /// `Favourites`
  String get Favourites {
    return Intl.message('Favourites', name: 'Favourites', desc: '', args: []);
  }

  /// `Downloads`
  String get Downloads {
    return Intl.message('Downloads', name: 'Downloads', desc: '', args: []);
  }

  /// `History`
  String get History {
    return Intl.message('History', name: 'History', desc: '', args: []);
  }

  /// `{count, plural, =0{No Songs} =1{1 Song} other{{count} Songs}}`
  String nSongs(num count) {
    return Intl.plural(
      count,
      zero: 'No Songs',
      one: '1 Song',
      other: '$count Songs',
      name: 'nSongs',
      desc: 'Number of songs',
      args: [count],
    );
  }

  /// `Songs`
  String get Songs {
    return Intl.message('Songs', name: 'Songs', desc: '', args: []);
  }

  /// `Albums`
  String get Albums {
    return Intl.message('Albums', name: 'Albums', desc: '', args: []);
  }

  /// `Playlists`
  String get Playlists {
    return Intl.message('Playlists', name: 'Playlists', desc: '', args: []);
  }

  /// `Artists`
  String get Artists {
    return Intl.message('Artists', name: 'Artists', desc: '', args: []);
  }

  /// `Subscriptions`
  String get Subscriptions {
    return Intl.message(
      'Subscriptions',
      name: 'Subscriptions',
      desc: '',
      args: [],
    );
  }

  /// `Search Settings`
  String get Search_Settings {
    return Intl.message(
      'Search Settings',
      name: 'Search_Settings',
      desc: '',
      args: [],
    );
  }

  /// `Battery Optimisation Detected`
  String get Battery_Optimisation_title {
    return Intl.message(
      'Battery Optimisation Detected',
      name: 'Battery_Optimisation_title',
      desc: '',
      args: [],
    );
  }

  /// `Click here disable battery optimisation for Echo to work properly`
  String get Battery_Optimisation_message {
    return Intl.message(
      'Click here disable battery optimisation for Echo to work properly',
      name: 'Battery_Optimisation_message',
      desc: '',
      args: [],
    );
  }

  /// `Donate`
  String get Donate {
    return Intl.message('Donate', name: 'Donate', desc: '', args: []);
  }

  /// `Support the development of Echo`
  String get Donate_Message {
    return Intl.message(
      'Support the development of Echo',
      name: 'Donate_Message',
      desc: '',
      args: [],
    );
  }

  /// `Payment Methods`
  String get Payment_Methods {
    return Intl.message(
      'Payment Methods',
      name: 'Payment_Methods',
      desc: '',
      args: [],
    );
  }

  /// `Pay with UPI`
  String get Pay_With_UPI {
    return Intl.message(
      'Pay with UPI',
      name: 'Pay_With_UPI',
      desc: '',
      args: [],
    );
  }

  /// `Support me on Ko-fi`
  String get Support_Me_On_Kofi {
    return Intl.message(
      'Support me on Ko-fi',
      name: 'Support_Me_On_Kofi',
      desc: '',
      args: [],
    );
  }

  /// `Buy me a Coffee`
  String get Buy_Me_A_Coffee {
    return Intl.message(
      'Buy me a Coffee',
      name: 'Buy_Me_A_Coffee',
      desc: '',
      args: [],
    );
  }

  /// `Google Account`
  String get Google_Account {
    return Intl.message(
      'Google Account',
      name: 'Google_Account',
      desc: '',
      args: [],
    );
  }

  /// `Appearence`
  String get Appearence {
    return Intl.message('Appearence', name: 'Appearence', desc: '', args: []);
  }

  /// `Theme Mode`
  String get Theme_Mode {
    return Intl.message('Theme Mode', name: 'Theme_Mode', desc: '', args: []);
  }

  /// `Window Effect`
  String get Window_Effect {
    return Intl.message(
      'Window Effect',
      name: 'Window_Effect',
      desc: '',
      args: [],
    );
  }

  /// `Dynamic Colors`
  String get Dynamic_Colors {
    return Intl.message(
      'Dynamic Colors',
      name: 'Dynamic_Colors',
      desc: '',
      args: [],
    );
  }

  /// `Content`
  String get Content {
    return Intl.message('Content', name: 'Content', desc: '', args: []);
  }

  /// `Country`
  String get Country {
    return Intl.message('Country', name: 'Country', desc: '', args: []);
  }

  /// `Language`
  String get Language {
    return Intl.message('Language', name: 'Language', desc: '', args: []);
  }

  /// `Translate Lyrics`
  String get Translate_Lyrics {
    return Intl.message(
      'Translate Lyrics',
      name: 'Translate_Lyrics',
      desc: '',
      args: [],
    );
  }

  /// `Autoplay Similar Songs`
  String get Autofetch_Songs {
    return Intl.message(
      'Autoplay Similar Songs',
      name: 'Autofetch_Songs',
      desc: '',
      args: [],
    );
  }

  /// `Personalised Content`
  String get Personalised_Content {
    return Intl.message(
      'Personalised Content',
      name: 'Personalised_Content',
      desc: '',
      args: [],
    );
  }

  /// `Enter Visitor Id`
  String get Enter_Visitor_Id {
    return Intl.message(
      'Enter Visitor Id',
      name: 'Enter_Visitor_Id',
      desc: '',
      args: [],
    );
  }

  /// `Visitor Id`
  String get Visitor_Id {
    return Intl.message('Visitor Id', name: 'Visitor_Id', desc: '', args: []);
  }

  /// `Reset Visitor Id`
  String get Reset_Visitor_Id {
    return Intl.message(
      'Reset Visitor Id',
      name: 'Reset_Visitor_Id',
      desc: '',
      args: [],
    );
  }

  /// `Audio and Playback`
  String get Audio_And_Playback {
    return Intl.message(
      'Audio and Playback',
      name: 'Audio_And_Playback',
      desc: '',
      args: [],
    );
  }

  /// `Loudness And Equalizer`
  String get Loudness_And_Equalizer {
    return Intl.message(
      'Loudness And Equalizer',
      name: 'Loudness_And_Equalizer',
      desc: '',
      args: [],
    );
  }

  /// `Loudness Enhancer`
  String get Loudness_Enhancer {
    return Intl.message(
      'Loudness Enhancer',
      name: 'Loudness_Enhancer',
      desc: '',
      args: [],
    );
  }

  /// `Enable Equalizer`
  String get Enable_Equalizer {
    return Intl.message(
      'Enable Equalizer',
      name: 'Enable_Equalizer',
      desc: '',
      args: [],
    );
  }

  /// `Streaming Quality`
  String get Streaming_Quality {
    return Intl.message(
      'Streaming Quality',
      name: 'Streaming_Quality',
      desc: '',
      args: [],
    );
  }

  /// `Download Quality`
  String get DOwnload_Quality {
    return Intl.message(
      'Download Quality',
      name: 'DOwnload_Quality',
      desc: '',
      args: [],
    );
  }

  /// `App Folder`
  String get App_Folder {
    return Intl.message('App Folder', name: 'App_Folder', desc: '', args: []);
  }

  /// `Skip Silence`
  String get Skip_Silence {
    return Intl.message(
      'Skip Silence',
      name: 'Skip_Silence',
      desc: '',
      args: [],
    );
  }

  /// `Enable Playback History`
  String get Enable_Playback_History {
    return Intl.message(
      'Enable Playback History',
      name: 'Enable_Playback_History',
      desc: '',
      args: [],
    );
  }

  /// `Delete Playback History`
  String get Delete_Playback_History {
    return Intl.message(
      'Delete Playback History',
      name: 'Delete_Playback_History',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete Playback History.`
  String get Delete_Playback_History_Confirm_Message {
    return Intl.message(
      'Are you sure you want to delete Playback History.',
      name: 'Delete_Playback_History_Confirm_Message',
      desc: '',
      args: [],
    );
  }

  /// `Playback History Deleted`
  String get Playback_History_Deleted {
    return Intl.message(
      'Playback History Deleted',
      name: 'Playback_History_Deleted',
      desc: '',
      args: [],
    );
  }

  /// `Enable Search History`
  String get Enable_Search_History {
    return Intl.message(
      'Enable Search History',
      name: 'Enable_Search_History',
      desc: '',
      args: [],
    );
  }

  /// `Delete Search History`
  String get Delete_Search_History {
    return Intl.message(
      'Delete Search History',
      name: 'Delete_Search_History',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete Search History.`
  String get Delete_Search_History_Confirm_Message {
    return Intl.message(
      'Are you sure you want to delete Search History.',
      name: 'Delete_Search_History_Confirm_Message',
      desc: '',
      args: [],
    );
  }

  /// `Search History Deleted`
  String get Search_History_Deleted {
    return Intl.message(
      'Search History Deleted',
      name: 'Search_History_Deleted',
      desc: '',
      args: [],
    );
  }

  /// `Backup and Restore`
  String get Backup_And_Restore {
    return Intl.message(
      'Backup and Restore',
      name: 'Backup_And_Restore',
      desc: '',
      args: [],
    );
  }

  /// `Backup`
  String get Backup {
    return Intl.message('Backup', name: 'Backup', desc: '', args: []);
  }

  /// `Restore`
  String get Restore {
    return Intl.message('Restore', name: 'Restore', desc: '', args: []);
  }

  /// `Share`
  String get Share {
    return Intl.message('Share', name: 'Share', desc: '', args: []);
  }

  /// `Save`
  String get Save {
    return Intl.message('Save', name: 'Save', desc: '', args: []);
  }

  /// `Backed up successfully at`
  String get Backup_Success {
    return Intl.message(
      'Backed up successfully at',
      name: 'Backup_Success',
      desc: '',
      args: [],
    );
  }

  /// `Failed to back up Data`
  String get Backup_Failed {
    return Intl.message(
      'Failed to back up Data',
      name: 'Backup_Failed',
      desc: '',
      args: [],
    );
  }

  /// `Data successfully restored`
  String get Restore_Success {
    return Intl.message(
      'Data successfully restored',
      name: 'Restore_Success',
      desc: '',
      args: [],
    );
  }

  /// `Failed to restore Data`
  String get Restore_Failed {
    return Intl.message(
      'Failed to restore Data',
      name: 'Restore_Failed',
      desc: '',
      args: [],
    );
  }

  /// `Select Backup`
  String get Select_Backup {
    return Intl.message(
      'Select Backup',
      name: 'Select_Backup',
      desc: '',
      args: [],
    );
  }

  /// `About`
  String get About {
    return Intl.message('About', name: 'About', desc: '', args: []);
  }

  /// `Name`
  String get Name {
    return Intl.message('Name', name: 'Name', desc: '', args: []);
  }

  /// `Version`
  String get Version {
    return Intl.message('Version', name: 'Version', desc: '', args: []);
  }

  /// `Developer`
  String get Developer {
    return Intl.message('Developer', name: 'Developer', desc: '', args: []);
  }

  /// `Sheikh Haziq`
  String get Sheikh_Haziq {
    return Intl.message(
      'Sheikh Haziq',
      name: 'Sheikh_Haziq',
      desc: '',
      args: [],
    );
  }

  /// `Organisation`
  String get Organisation {
    return Intl.message(
      'Organisation',
      name: 'Organisation',
      desc: '',
      args: [],
    );
  }

  /// `Jhelum Corp`
  String get Jhelum_Corp {
    return Intl.message('Jhelum Corp', name: 'Jhelum_Corp', desc: '', args: []);
  }

  /// `Telegram`
  String get Telegram {
    return Intl.message('Telegram', name: 'Telegram', desc: '', args: []);
  }

  /// `Contributors`
  String get Contributors {
    return Intl.message(
      'Contributors',
      name: 'Contributors',
      desc: '',
      args: [],
    );
  }

  /// `Source Code`
  String get Source_Code {
    return Intl.message('Source Code', name: 'Source_Code', desc: '', args: []);
  }

  /// `Bug Report`
  String get Bug_Report {
    return Intl.message('Bug Report', name: 'Bug_Report', desc: '', args: []);
  }

  /// `Feature Request`
  String get Feature_Request {
    return Intl.message(
      'Feature Request',
      name: 'Feature_Request',
      desc: '',
      args: [],
    );
  }

  /// `Made in Kashmir`
  String get Made_In_Kashmir {
    return Intl.message(
      'Made in Kashmir',
      name: 'Made_In_Kashmir',
      desc: '',
      args: [],
    );
  }

  /// `Check for Update`
  String get Check_For_Update {
    return Intl.message(
      'Check for Update',
      name: 'Check_For_Update',
      desc: '',
      args: [],
    );
  }

  /// `Progress`
  String get Progress {
    return Intl.message('Progress', name: 'Progress', desc: '', args: []);
  }

  /// `Play Next`
  String get Play_Next {
    return Intl.message('Play Next', name: 'Play_Next', desc: '', args: []);
  }

  /// `Add To Queue`
  String get Add_To_Queue {
    return Intl.message(
      'Add To Queue',
      name: 'Add_To_Queue',
      desc: '',
      args: [],
    );
  }

  /// `Add To Favourites`
  String get Add_To_Favourites {
    return Intl.message(
      'Add To Favourites',
      name: 'Add_To_Favourites',
      desc: '',
      args: [],
    );
  }

  /// `Remove From Favourites`
  String get Remove_From_Favourites {
    return Intl.message(
      'Remove From Favourites',
      name: 'Remove_From_Favourites',
      desc: '',
      args: [],
    );
  }

  /// `Download`
  String get Download {
    return Intl.message('Download', name: 'Download', desc: '', args: []);
  }

  /// `Add To Playlist`
  String get Add_To_Playlist {
    return Intl.message(
      'Add To Playlist',
      name: 'Add_To_Playlist',
      desc: '',
      args: [],
    );
  }

  /// `Start Radio`
  String get Start_Radio {
    return Intl.message('Start Radio', name: 'Start_Radio', desc: '', args: []);
  }

  /// `Album`
  String get Album {
    return Intl.message('Album', name: 'Album', desc: '', args: []);
  }

  /// `Rename`
  String get Rename {
    return Intl.message('Rename', name: 'Rename', desc: '', args: []);
  }

  /// `Add To Library`
  String get Add_To_Library {
    return Intl.message(
      'Add To Library',
      name: 'Add_To_Library',
      desc: '',
      args: [],
    );
  }

  /// `Remove From Library`
  String get Remove_From_Library {
    return Intl.message(
      'Remove From Library',
      name: 'Remove_From_Library',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete this item?`
  String get Delete_Item_Message {
    return Intl.message(
      'Are you sure you want to delete this item?',
      name: 'Delete_Item_Message',
      desc: '',
      args: [],
    );
  }

  /// `Equalizer`
  String get Equalizer {
    return Intl.message('Equalizer', name: 'Equalizer', desc: '', args: []);
  }

  /// `Sleep Timer`
  String get Sleep_Timer {
    return Intl.message('Sleep Timer', name: 'Sleep_Timer', desc: '', args: []);
  }

  /// `Create Playlist`
  String get Create_Playlist {
    return Intl.message(
      'Create Playlist',
      name: 'Create_Playlist',
      desc: '',
      args: [],
    );
  }

  /// `Playlist Name`
  String get Playlist_Name {
    return Intl.message(
      'Playlist Name',
      name: 'Playlist_Name',
      desc: '',
      args: [],
    );
  }

  /// `Create`
  String get Create {
    return Intl.message('Create', name: 'Create', desc: '', args: []);
  }

  /// `Import Playlist`
  String get Import_Playlist {
    return Intl.message(
      'Import Playlist',
      name: 'Import_Playlist',
      desc: '',
      args: [],
    );
  }

  /// `Import`
  String get Import {
    return Intl.message('Import', name: 'Import', desc: '', args: []);
  }

  /// `Rename Playlist`
  String get Rename_Playlist {
    return Intl.message(
      'Rename Playlist',
      name: 'Rename_Playlist',
      desc: '',
      args: [],
    );
  }

  /// `Done`
  String get Done {
    return Intl.message('Done', name: 'Done', desc: '', args: []);
  }

  /// `Cancel`
  String get Cancel {
    return Intl.message('Cancel', name: 'Cancel', desc: '', args: []);
  }

  /// `Confirm`
  String get Confirm {
    return Intl.message('Confirm', name: 'Confirm', desc: '', args: []);
  }

  /// `Yes`
  String get Yes {
    return Intl.message('Yes', name: 'Yes', desc: '', args: []);
  }

  /// `No`
  String get No {
    return Intl.message('No', name: 'No', desc: '', args: []);
  }

  /// `Show More`
  String get Show_More {
    return Intl.message('Show More', name: 'Show_More', desc: '', args: []);
  }

  /// `Show Less`
  String get Show_Less {
    return Intl.message('Show Less', name: 'Show_Less', desc: '', args: []);
  }

  /// `Remove`
  String get Remove {
    return Intl.message('Remove', name: 'Remove', desc: '', args: []);
  }

  /// `High`
  String get High {
    return Intl.message('High', name: 'High', desc: '', args: []);
  }

  /// `Low`
  String get Low {
    return Intl.message('Low', name: 'Low', desc: '', args: []);
  }

  /// `Songs will start playing soon.`
  String get Songs_Will_Start_Playing_Soon {
    return Intl.message(
      'Songs will start playing soon.',
      name: 'Songs_Will_Start_Playing_Soon',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to remove it?`
  String get Remove_Message {
    return Intl.message(
      'Are you sure you want to remove it?',
      name: 'Remove_Message',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to remove it from YTMusic?`
  String get Remove_From_YTMusic_Message {
    return Intl.message(
      'Are you sure you want to remove it from YTMusic?',
      name: 'Remove_From_YTMusic_Message',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to clear all history?`
  String get Remove_All_History_Message {
    return Intl.message(
      'Are you sure you want to clear all history?',
      name: 'Remove_All_History_Message',
      desc: '',
      args: [],
    );
  }

  /// `Copied to Clipboard`
  String get Copied_To_Clipboard {
    return Intl.message(
      'Copied to Clipboard',
      name: 'Copied_To_Clipboard',
      desc: '',
      args: [],
    );
  }

  /// `No Internet Connection`
  String get No_Internet_Connection {
    return Intl.message(
      'No Internet Connection',
      name: 'No_Internet_Connection',
      desc: '',
      args: [],
    );
  }

  /// `Go to Downloads`
  String get Go_To_Downloads {
    return Intl.message(
      'Go to Downloads',
      name: 'Go_To_Downloads',
      desc: '',
      args: [],
    );
  }

  /// `Retry`
  String get Retry {
    return Intl.message('Retry', name: 'Retry', desc: '', args: []);
  }

  /// `Playlist not available`
  String get Playlist_Not_Available {
    return Intl.message(
      'Playlist not available',
      name: 'Playlist_Not_Available',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete them?`
  String get Confirm_Delete_All_Message {
    return Intl.message(
      'Are you sure you want to delete them?',
      name: 'Confirm_Delete_All_Message',
      desc: '',
      args: [],
    );
  }

  /// `Downloading`
  String get Downloading {
    return Intl.message('Downloading', name: 'Downloading', desc: '', args: []);
  }

  /// `Restore Missing Songs`
  String get Restore_Missing_Songs {
    return Intl.message(
      'Restore Missing Songs',
      name: 'Restore_Missing_Songs',
      desc: '',
      args: [],
    );
  }

  /// `Delete All Songs`
  String get Delete_All_Songs {
    return Intl.message(
      'Delete All Songs',
      name: 'Delete_All_Songs',
      desc: '',
      args: [],
    );
  }

  /// `Download started...`
  String get Download_Started {
    return Intl.message(
      'Download started...',
      name: 'Download_Started',
      desc: '',
      args: [],
    );
  }

  /// `Restoring Missing Songs...`
  String get Restoring_Missing_Songs {
    return Intl.message(
      'Restoring Missing Songs...',
      name: 'Restoring_Missing_Songs',
      desc: '',
      args: [],
    );
  }

  /// `Deleting Songs...`
  String get Deleting_Songs {
    return Intl.message(
      'Deleting Songs...',
      name: 'Deleting_Songs',
      desc: '',
      args: [],
    );
  }

  /// `In Progress`
  String get In_Progress {
    return Intl.message('In Progress', name: 'In_Progress', desc: '', args: []);
  }

  /// `Queued`
  String get Queued {
    return Intl.message('Queued', name: 'Queued', desc: '', args: []);
  }

  /// `Queued ({count})`
  String QueuedCount(Object count) {
    return Intl.message(
      'Queued ($count)',
      name: 'QueuedCount',
      desc: '',
      args: [count],
    );
  }

  /// `File not found`
  String get FileNotFound {
    return Intl.message(
      'File not found',
      name: 'FileNotFound',
      desc: '',
      args: [],
    );
  }
  /// `10 bande applicate al filtro audio`
  String get M10BandeApplicateAlFiltroAudio {
    return Intl.message(
      '10 bande applicate al filtro audio',
      name: 'M10BandeApplicateAlFiltroAudio',
      desc: '',
      args: [],
    );
  }

  /// `AI lyrics & translation`
  String get AILyricsTranslation {
    return Intl.message(
      'AI lyrics & translation',
      name: 'AILyricsTranslation',
      desc: '',
      args: [],
    );
  }

  /// `AI-powered lyrics and translations`
  String get AIPoweredLyricsAndTranslations {
    return Intl.message(
      'AI-powered lyrics and translations',
      name: 'AIPoweredLyricsAndTranslations',
      desc: '',
      args: [],
    );
  }

  /// `API Credentials`
  String get APICredentials {
    return Intl.message(
      'API Credentials',
      name: 'APICredentials',
      desc: '',
      args: [],
    );
  }

  /// `API Key`
  String get APIKey {
    return Intl.message(
      'API Key',
      name: 'APIKey',
      desc: '',
      args: [],
    );
  }

  /// `AXION / AutoEq engine`
  String get AXIONAutoEqEngine {
    return Intl.message(
      'AXION / AutoEq engine',
      name: 'AXIONAutoEqEngine',
      desc: '',
      args: [],
    );
  }

  /// `AXION / AutoEq equalizer`
  String get AXIONAutoEqEqualizer {
    return Intl.message(
      'AXION / AutoEq equalizer',
      name: 'AXIONAutoEqEqualizer',
      desc: '',
      args: [],
    );
  }

  /// `AccentColor`
  String get AccentColor {
    return Intl.message(
      'AccentColor',
      name: 'AccentColor',
      desc: '',
      args: [],
    );
  }

  /// `Account`
  String get Account {
    return Intl.message(
      'Account',
      name: 'Account',
      desc: '',
      args: [],
    );
  }

  /// `Add 5 extra seconds on each seek`
  String get Add5ExtraSecondsOnEachSeek {
    return Intl.message(
      'Add 5 extra seconds on each seek',
      name: 'Add5ExtraSecondsOnEachSeek',
      desc: '',
      args: [],
    );
  }

  /// `Add similar songs at the end of the queue`
  String get AddSimilarSongsAtTheEndOfTheQueue {
    return Intl.message(
      'Add similar songs at the end of the queue',
      name: 'AddSimilarSongsAtTheEndOfTheQueue',
      desc: '',
      args: [],
    );
  }

  /// `Add songs when the queue runs low`
  String get AddSongsWhenTheQueueRunsLow {
    return Intl.message(
      'Add songs when the queue runs low',
      name: 'AddSongsWhenTheQueueRunsLow',
      desc: '',
      args: [],
    );
  }

  /// `Advanced playback`
  String get AdvancedPlayback {
    return Intl.message(
      'Advanced playback',
      name: 'AdvancedPlayback',
      desc: '',
      args: [],
    );
  }

  /// `Amoled Black`
  String get AmoledBlack {
    return Intl.message(
      'Amoled Black',
      name: 'AmoledBlack',
      desc: '',
      args: [],
    );
  }

  /// `Annulla`
  String get Annulla {
    return Intl.message(
      'Cancel',
      name: 'Annulla',
      desc: '',
      args: [],
    );
  }

  /// `App info and licenses`
  String get AppInfoAndLicenses {
    return Intl.message(
      'App info and licenses',
      name: 'AppInfoAndLicenses',
      desc: '',
      args: [],
    );
  }

  /// `Appearance extras`
  String get AppearanceExtras {
    return Intl.message(
      'Appearance extras',
      name: 'AppearanceExtras',
      desc: '',
      args: [],
    );
  }

  /// `Apri cartella export`
  String get ApriCartellaExport {
    return Intl.message(
      'Open export folder',
      name: 'ApriCartellaExport',
      desc: '',
      args: [],
    );
  }

  /// `Audio normalization`
  String get AudioNormalization {
    return Intl.message(
      'Audio normalization',
      name: 'AudioNormalization',
      desc: '',
      args: [],
    );
  }

  /// `Audio output`
  String get AudioOutput {
    return Intl.message(
      'Audio output',
      name: 'AudioOutput',
      desc: '',
      args: [],
    );
  }

  /// `Audio processing`
  String get AudioProcessing {
    return Intl.message(
      'Audio processing',
      name: 'AudioProcessing',
      desc: '',
      args: [],
    );
  }

  /// `Audio quality ceiling over Wi-Fi / network`
  String get AudioQualityCeilingOverWiFiNetwork {
    return Intl.message(
      'Audio quality ceiling over Wi-Fi / network',
      name: 'AudioQualityCeilingOverWiFiNetwork',
      desc: '',
      args: [],
    );
  }

  /// `Auto download on like`
  String get AutoDownloadOnLike {
    return Intl.message(
      'Auto download on like',
      name: 'AutoDownloadOnLike',
      desc: '',
      args: [],
    );
  }

  /// `Auto load more songs`
  String get AutoLoadMoreSongs {
    return Intl.message(
      'Auto load more songs',
      name: 'AutoLoadMoreSongs',
      desc: '',
      args: [],
    );
  }

  /// `Auto playlists`
  String get AutoPlaylists {
    return Intl.message(
      'Auto playlists',
      name: 'AutoPlaylists',
      desc: '',
      args: [],
    );
  }

  /// `Auto scroll lyrics`
  String get AutoScrollLyrics {
    return Intl.message(
      'Auto scroll lyrics',
      name: 'AutoScrollLyrics',
      desc: '',
      args: [],
    );
  }

  /// `Auto skip to next song on error`
  String get AutoSkipToNextSongOnError {
    return Intl.message(
      'Auto skip to next song on error',
      name: 'AutoSkipToNextSongOnError',
      desc: '',
      args: [],
    );
  }

  /// `Automix · allinea al beat`
  String get AutomixAllineaAlBeat {
    return Intl.message(
      'Automix · allinea al beat',
      name: 'AutomixAllineaAlBeat',
      desc: '',
      args: [],
    );
  }

  /// `Automix · mixing armonico`
  String get AutomixMixingArmonico {
    return Intl.message(
      'Automix · mixing armonico',
      name: 'AutomixMixingArmonico',
      desc: '',
      args: [],
    );
  }

  /// `Background export task queue`
  String get BackgroundExportTaskQueue {
    return Intl.message(
      'Background export task queue',
      name: 'BackgroundExportTaskQueue',
      desc: '',
      args: [],
    );
  }

  /// `Base URL`
  String get BaseURL {
    return Intl.message(
      'Base URL',
      name: 'BaseURL',
      desc: '',
      args: [],
    );
  }

  /// `Bit-perfect USB DAC output`
  String get BitPerfectUSBDACOutput {
    return Intl.message(
      'Bit-perfect USB DAC output',
      name: 'BitPerfectUSBDACOutput',
      desc: '',
      args: [],
    );
  }

  String get VideoBehindArtwork {
    return Intl.message(
      'Video behind artwork (full screen)',
      name: 'VideoBehindArtwork',
      desc: '',
      args: [],
    );
  }

  /// `Blend the end of a song into the next`
  String get BlendTheEndOfASongIntoTheNext {
    return Intl.message(
      'Blend the end of a song into the next',
      name: 'BlendTheEndOfASongIntoTheNext',
      desc: '',
      args: [],
    );
  }

  /// `Blocked Artists`
  String get BlockedArtists {
    return Intl.message(
      'Blocked Artists',
      name: 'BlockedArtists',
      desc: '',
      args: [],
    );
  }

  /// `Cache and downloads`
  String get CacheAndDownloads {
    return Intl.message(
      'Cache and downloads',
      name: 'CacheAndDownloads',
      desc: '',
      args: [],
    );
  }

  /// `Cache the next song for gapless playback`
  String get CacheTheNextSongForGaplessPlayback {
    return Intl.message(
      'Cache the next song for gapless playback',
      name: 'CacheTheNextSongForGaplessPlayback',
      desc: '',
      args: [],
    );
  }

  /// `Canvas & Ambient mode`
  String get CanvasAmbientMode {
    return Intl.message(
      'Canvas & Ambient mode',
      name: 'CanvasAmbientMode',
      desc: '',
      args: [],
    );
  }

  /// `Cast & remote control`
  String get CastRemoteControl {
    return Intl.message(
      'Cast & remote control',
      name: 'CastRemoteControl',
      desc: '',
      args: [],
    );
  }

  /// `Clear all`
  String get ClearAll {
    return Intl.message(
      'Clear all',
      name: 'ClearAll',
      desc: '',
      args: [],
    );
  }

  /// `Clear image cache`
  String get ClearImageCache {
    return Intl.message(
      'Clear image cache',
      name: 'ClearImageCache',
      desc: '',
      args: [],
    );
  }

  /// `Clear song cache`
  String get ClearSongCache {
    return Intl.message(
      'Clear song cache',
      name: 'ClearSongCache',
      desc: '',
      args: [],
    );
  }

  /// `Coming in a future update`
  String get ComingInAFutureUpdate {
    return Intl.message(
      'Coming in a future update',
      name: 'ComingInAFutureUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Configure`
  String get Configure {
    return Intl.message(
      'Configure',
      name: 'Configure',
      desc: '',
      args: [],
    );
  }

  /// `Crossfade`
  String get Crossfade {
    return Intl.message(
      'Crossfade',
      name: 'Crossfade',
      desc: '',
      args: [],
    );
  }

  /// `Data Saver`
  String get DataSaver {
    return Intl.message(
      'Data Saver',
      name: 'DataSaver',
      desc: '',
      args: [],
    );
  }

  /// `Default content country`
  String get DefaultContentCountry {
    return Intl.message(
      'Default content country',
      name: 'DefaultContentCountry',
      desc: '',
      args: [],
    );
  }

  /// `Default content language`
  String get DefaultContentLanguage {
    return Intl.message(
      'Default content language',
      name: 'DefaultContentLanguage',
      desc: '',
      args: [],
    );
  }

  /// `Default open tab`
  String get DefaultOpenTab {
    return Intl.message(
      'Default open tab',
      name: 'DefaultOpenTab',
      desc: '',
      args: [],
    );
  }

  /// `Diagnostica Automix`
  String get DiagnosticaAutomix {
    return Intl.message(
      'Diagnostica Automix',
      name: 'DiagnosticaAutomix',
      desc: '',
      args: [],
    );
  }

  /// `Discord Rich Presence`
  String get DiscordRichPresence {
    return Intl.message(
      'Discord Rich Presence',
      name: 'DiscordRichPresence',
      desc: '',
      args: [],
    );
  }

  /// `Disliked Songs`
  String get DislikedSongs {
    return Intl.message(
      'Disliked Songs',
      name: 'DislikedSongs',
      desc: '',
      args: [],
    );
  }

  /// `Echo Wrapped`
  String get EchoWrapped {
    return Intl.message(
      'Echo Wrapped',
      name: 'EchoWrapped',
      desc: '',
      args: [],
    );
  }

  /// `EchoBrain playlists`
  String get EchoBrainPlaylists {
    return Intl.message(
      'EchoBrain playlists',
      name: 'EchoBrainPlaylists',
      desc: '',
      args: [],
    );
  }

  /// `Enable Cast device discovery`
  String get EnableCastDeviceDiscovery {
    return Intl.message(
      'Enable Cast device discovery',
      name: 'EnableCastDeviceDiscovery',
      desc: '',
      args: [],
    );
  }

  /// `Enable similar content`
  String get EnableSimilarContent {
    return Intl.message(
      'Enable similar content',
      name: 'EnableSimilarContent',
      desc: '',
      args: [],
    );
  }

  /// `Export and import data`
  String get ExportAndImportData {
    return Intl.message(
      'Export and import data',
      name: 'ExportAndImportData',
      desc: '',
      args: [],
    );
  }

  /// `Export as MP3`
  String get ExportAsMP3 {
    return Intl.message(
      'Export as MP3',
      name: 'ExportAsMP3',
      desc: '',
      args: [],
    );
  }

  /// `Extensions & high-quality servers`
  String get ExtensionsHighQualityServers {
    return Intl.message(
      'Extensions & high-quality servers',
      name: 'ExtensionsHighQualityServers',
      desc: '',
      args: [],
    );
  }

  /// `Fetch song background`
  String get FetchSongBackground {
    return Intl.message(
      'Fetch song background',
      name: 'FetchSongBackground',
      desc: '',
      args: [],
    );
  }

  /// `Fine-grained options`
  String get FineGrainedOptions {
    return Intl.message(
      'Fine-grained options',
      name: 'FineGrainedOptions',
      desc: '',
      args: [],
    );
  }

  /// `Force low bitrate and disable preloading`
  String get ForceLowBitrateAndDisablePreloading {
    return Intl.message(
      'Force low bitrate and disable preloading',
      name: 'ForceLowBitrateAndDisablePreloading',
      desc: '',
      args: [],
    );
  }

  /// `General`
  String get General {
    return Intl.message(
      'General',
      name: 'General',
      desc: '',
      args: [],
    );
  }

  /// `Glass effect`
  String get GlassEffect {
    return Intl.message(
      'Glass effect',
      name: 'GlassEffect',
      desc: '',
      args: [],
    );
  }

  /// `Glass, player, lyrics & misc customization`
  String get GlassPlayerLyricsMiscCustomization {
    return Intl.message(
      'Glass, player, lyrics & misc customization',
      name: 'GlassPlayerLyricsMiscCustomization',
      desc: '',
      args: [],
    );
  }

  /// `Google Cast`
  String get GoogleCast {
    return Intl.message(
      'Google Cast',
      name: 'GoogleCast',
      desc: '',
      args: [],
    );
  }

  /// `Hide Player Thumbnail`
  String get HidePlayerThumbnail {
    return Intl.message(
      'Hide Player Thumbnail',
      name: 'HidePlayerThumbnail',
      desc: '',
      args: [],
    );
  }

  /// `Hide YouTube Shorts`
  String get HideYouTubeShorts {
    return Intl.message(
      'Hide YouTube Shorts',
      name: 'HideYouTubeShorts',
      desc: '',
      args: [],
    );
  }

  /// `Hide explicit content`
  String get HideExplicitContent {
    return Intl.message(
      'Hide explicit content',
      name: 'HideExplicitContent',
      desc: '',
      args: [],
    );
  }

  /// `Hide video songs`
  String get HideVideoSongs {
    return Intl.message(
      'Hide video songs',
      name: 'HideVideoSongs',
      desc: '',
      args: [],
    );
  }

  /// `History and tracking`
  String get HistoryAndTracking {
    return Intl.message(
      'History and tracking',
      name: 'HistoryAndTracking',
      desc: '',
      args: [],
    );
  }

  /// `Il blend finisce su un beat della traccia`
  String get IlBlendFinisceSuUnBeatDellaTraccia {
    return Intl.message(
      'Il blend finisce su un beat della traccia',
      name: 'IlBlendFinisceSuUnBeatDellaTraccia',
      desc: '',
      args: [],
    );
  }

  /// `Image Cache`
  String get ImageCache {
    return Intl.message(
      'Image Cache',
      name: 'ImageCache',
      desc: '',
      args: [],
    );
  }

  /// `Import a playlist by URL`
  String get ImportAPlaylistByURL {
    return Intl.message(
      'Import a playlist by URL',
      name: 'ImportAPlaylistByURL',
      desc: '',
      args: [],
    );
  }

  /// `Import from Spotify`
  String get ImportFromSpotify {
    return Intl.message(
      'Import from Spotify',
      name: 'ImportFromSpotify',
      desc: '',
      args: [],
    );
  }

  /// `Incolla profilo AutoEq (avanzato)`
  String get IncollaProfiloAutoEqAvanzato {
    return Intl.message(
      'Incolla profilo AutoEq (avanzato)',
      name: 'IncollaProfiloAutoEqAvanzato',
      desc: '',
      args: [],
    );
  }

  /// `Jellyfin / Navidrome`
  String get JellyfinNavidrome {
    return Intl.message(
      'Jellyfin / Navidrome',
      name: 'JellyfinNavidrome',
      desc: '',
      args: [],
    );
  }

  /// `Language, region, and providers`
  String get LanguageRegionAndProviders {
    return Intl.message(
      'Language, region, and providers',
      name: 'LanguageRegionAndProviders',
      desc: '',
      args: [],
    );
  }

  /// `Last.fm / ListenBrainz`
  String get LastFmListenBrainz {
    return Intl.message(
      'Last.fm / ListenBrainz',
      name: 'LastFmListenBrainz',
      desc: '',
      args: [],
    );
  }

  /// `Leave empty for the provider default`
  String get LeaveEmptyForTheProviderDefault {
    return Intl.message(
      'Leave empty for the provider default',
      name: 'LeaveEmptyForTheProviderDefault',
      desc: '',
      args: [],
    );
  }

  /// `Listen Together`
  String get ListenTogether {
    return Intl.message(
      'Listen Together',
      name: 'ListenTogether',
      desc: '',
      args: [],
    );
  }

  /// `Listening Summary`
  String get ListeningSummary {
    return Intl.message(
      'Listening Summary',
      name: 'ListeningSummary',
      desc: '',
      args: [],
    );
  }

  /// `Log eventi`
  String get LogEventi {
    return Intl.message(
      'Log eventi',
      name: 'LogEventi',
      desc: '',
      args: [],
    );
  }

  /// `Look up a track on Genius / Wikipedia`
  String get LookUpATrackOnGeniusWikipedia {
    return Intl.message(
      'Look up a track on Genius / Wikipedia',
      name: 'LookUpATrackOnGeniusWikipedia',
      desc: '',
      args: [],
    );
  }

  /// `Loudness preset`
  String get LoudnessPreset {
    return Intl.message(
      'Loudness preset',
      name: 'LoudnessPreset',
      desc: '',
      args: [],
    );
  }

  /// `Lyrics`
  String get Lyrics {
    return Intl.message(
      'Lyrics',
      name: 'Lyrics',
      desc: '',
      args: [],
    );
  }

  /// `Lyrics romanization`
  String get LyricsRomanization {
    return Intl.message(
      'Lyrics romanization',
      name: 'LyricsRomanization',
      desc: '',
      args: [],
    );
  }

  /// `Lyrics text position`
  String get LyricsTextPosition {
    return Intl.message(
      'Lyrics text position',
      name: 'LyricsTextPosition',
      desc: '',
      args: [],
    );
  }

  /// `Manage hidden artists`
  String get ManageHiddenArtists {
    return Intl.message(
      'Manage hidden artists',
      name: 'ManageHiddenArtists',
      desc: '',
      args: [],
    );
  }

  /// `Manage songs you dislike`
  String get ManageSongsYouDislike {
    return Intl.message(
      'Manage songs you dislike',
      name: 'ManageSongsYouDislike',
      desc: '',
      args: [],
    );
  }

  /// `Mini-player`
  String get MiniPlayer {
    return Intl.message(
      'Mini-player',
      name: 'MiniPlayer',
      desc: '',
      args: [],
    );
  }

  /// `Mini-player background style`
  String get MiniPlayerBackgroundStyle {
    return Intl.message(
      'Mini-player background style',
      name: 'MiniPlayerBackgroundStyle',
      desc: '',
      args: [],
    );
  }

  /// `Misc`
  String get Misc {
    return Intl.message(
      'Misc',
      name: 'Misc',
      desc: '',
      args: [],
    );
  }

  /// `Model`
  String get Model {
    return Intl.message(
      'Model',
      name: 'Model',
      desc: '',
      args: [],
    );
  }

  /// `Mostra overlay nel player`
  String get MostraOverlayNelPlayer {
    return Intl.message(
      'Mostra overlay nel player',
      name: 'MostraOverlayNelPlayer',
      desc: '',
      args: [],
    );
  }

  /// `Music Flow`
  String get MusicFlow {
    return Intl.message(
      'Music Flow',
      name: 'MusicFlow',
      desc: '',
      args: [],
    );
  }

  /// `Music Flow (full)`
  String get MusicFlowFull {
    return Intl.message(
      'Music Flow (full)',
      name: 'MusicFlowFull',
      desc: '',
      args: [],
    );
  }

  /// `Network`
  String get Network {
    return Intl.message(
      'Network',
      name: 'Network',
      desc: '',
      args: [],
    );
  }

  /// `Network & quality`
  String get NetworkQuality {
    return Intl.message(
      'Network & quality',
      name: 'NetworkQuality',
      desc: '',
      args: [],
    );
  }

  /// `Output device`
  String get OutputDevice {
    return Intl.message(
      'Output device',
      name: 'OutputDevice',
      desc: '',
      args: [],
    );
  }

  /// `Persistent queue`
  String get PersistentQueue {
    return Intl.message(
      'Persistent queue',
      name: 'PersistentQueue',
      desc: '',
      args: [],
    );
  }

  /// `Playback cutoff guard`
  String get PlaybackCutoffGuard {
    return Intl.message(
      'Playback cutoff guard',
      name: 'PlaybackCutoffGuard',
      desc: '',
      args: [],
    );
  }

  /// `Playback, quality, and equalizer`
  String get PlaybackQualityAndEqualizer {
    return Intl.message(
      'Playback, quality, and equalizer',
      name: 'PlaybackQualityAndEqualizer',
      desc: '',
      args: [],
    );
  }

  /// `Player`
  String get Player {
    return Intl.message(
      'Player',
      name: 'Player',
      desc: '',
      args: [],
    );
  }

  /// `Player and audio`
  String get PlayerAndAudio {
    return Intl.message(
      'Player and audio',
      name: 'PlayerAndAudio',
      desc: '',
      args: [],
    );
  }

  /// `Player background style`
  String get PlayerBackgroundStyle {
    return Intl.message(
      'Player background style',
      name: 'PlayerBackgroundStyle',
      desc: '',
      args: [],
    );
  }

  /// `Player look`
  String get PlayerLook {
    return Intl.message(
      'Player look',
      name: 'PlayerLook',
      desc: '',
      args: [],
    );
  }

  /// `Pre-arm adattivo attivo (20-35 s)`
  String get PreArmAdattivoAttivo2035S {
    return Intl.message(
      'Adaptive pre-arm active (20-35 s)',
      name: 'PreArmAdattivoAttivo2035S',
      desc: '',
      args: [],
    );
  }

  /// `Preload next song`
  String get PreloadNextSong {
    return Intl.message(
      'Preload next song',
      name: 'PreloadNextSong',
      desc: '',
      args: [],
    );
  }

  /// `Prevent duplicate tracks in queue`
  String get PreventDuplicateTracksInQueue {
    return Intl.message(
      'Prevent duplicate tracks in queue',
      name: 'PreventDuplicateTracksInQueue',
      desc: '',
      args: [],
    );
  }

  /// `Privacy`
  String get Privacy {
    return Intl.message(
      'Privacy',
      name: 'Privacy',
      desc: '',
      args: [],
    );
  }

  /// `Progressive seek`
  String get ProgressiveSeek {
    return Intl.message(
      'Progressive seek',
      name: 'ProgressiveSeek',
      desc: '',
      args: [],
    );
  }

  /// `Provider`
  String get Provider {
    return Intl.message(
      'Provider',
      name: 'Provider',
      desc: '',
      args: [],
    );
  }

  /// `Pulisci completate`
  String get PulisciCompletate {
    return Intl.message(
      'Clear completed',
      name: 'PulisciCompletate',
      desc: '',
      args: [],
    );
  }

  /// `Pulisci log`
  String get PulisciLog {
    return Intl.message(
      'Pulisci log',
      name: 'PulisciLog',
      desc: '',
      args: [],
    );
  }

  /// `Queue`
  String get Queue {
    return Intl.message(
      'Queue',
      name: 'Queue',
      desc: '',
      args: [],
    );
  }

  /// `Refresh devices`
  String get RefreshDevices {
    return Intl.message(
      'Refresh devices',
      name: 'RefreshDevices',
      desc: '',
      args: [],
    );
  }

  /// `Region`
  String get Region {
    return Intl.message(
      'Region',
      name: 'Region',
      desc: '',
      args: [],
    );
  }

  /// `Remember shuffle and repeat`
  String get RememberShuffleAndRepeat {
    return Intl.message(
      'Remember shuffle and repeat',
      name: 'RememberShuffleAndRepeat',
      desc: '',
      args: [],
    );
  }

  /// `Remote control (LAN)`
  String get RemoteControlLAN {
    return Intl.message(
      'Remote control (LAN)',
      name: 'RemoteControlLAN',
      desc: '',
      args: [],
    );
  }

  /// `ReplayGain loudness normalization (via playback gain)`
  String get ReplayGainLoudnessNormalizationViaPlaybackGain {
    return Intl.message(
      'ReplayGain loudness normalization (via playback gain)',
      name: 'ReplayGainLoudnessNormalizationViaPlaybackGain',
      desc: '',
      args: [],
    );
  }

  /// `Resso-style vertical swipe discovery`
  String get RessoStyleVerticalSwipeDiscovery {
    return Intl.message(
      'Resso-style vertical swipe discovery',
      name: 'RessoStyleVerticalSwipeDiscovery',
      desc: '',
      args: [],
    );
  }

  /// `Restore the last queue on app start`
  String get RestoreTheLastQueueOnAppStart {
    return Intl.message(
      'Restore the last queue on app start',
      name: 'RestoreTheLastQueueOnAppStart',
      desc: '',
      args: [],
    );
  }

  /// `Riprova`
  String get Riprova {
    return Intl.message(
      'Retry',
      name: 'Riprova',
      desc: '',
      args: [],
    );
  }

  /// `Sceglie il brano successivo in tonalità compatibile (Camelot)`
  String get SceglieIlBranoSuccessivoInTonalitCompatibileCame {
    return Intl.message(
      'Picks the next track in a compatible key (Camelot)',
      name: 'SceglieIlBranoSuccessivoInTonalitCompatibileCame',
      desc: '',
      args: [],
    );
  }

  /// `Show "Bottom" playlist`
  String get ShowBottomPlaylist {
    return Intl.message(
      'Show "Bottom" playlist',
      name: 'ShowBottomPlaylist',
      desc: '',
      args: [],
    );
  }

  /// `Show "Cached" playlist`
  String get ShowCachedPlaylist {
    return Intl.message(
      'Show "Cached" playlist',
      name: 'ShowCachedPlaylist',
      desc: '',
      args: [],
    );
  }

  /// `Show "Downloaded" playlist`
  String get ShowDownloadedPlaylist {
    return Intl.message(
      'Show "Downloaded" playlist',
      name: 'ShowDownloadedPlaylist',
      desc: '',
      args: [],
    );
  }

  /// `Show "Liked" playlist`
  String get ShowLikedPlaylist {
    return Intl.message(
      'Show "Liked" playlist',
      name: 'ShowLikedPlaylist',
      desc: '',
      args: [],
    );
  }

  /// `Show "Top" playlist`
  String get ShowTopPlaylist {
    return Intl.message(
      'Show "Top" playlist',
      name: 'ShowTopPlaylist',
      desc: '',
      args: [],
    );
  }

  /// `Show 10-second seek buttons`
  String get Show10SecondSeekButtons {
    return Intl.message(
      'Show 10-second seek buttons',
      name: 'Show10SecondSeekButtons',
      desc: '',
      args: [],
    );
  }

  /// `Show romanized lyrics as main`
  String get ShowRomanizedLyricsAsMain {
    return Intl.message(
      'Show romanized lyrics as main',
      name: 'ShowRomanizedLyricsAsMain',
      desc: '',
      args: [],
    );
  }

  /// `Skip silence`
  String get SkipSilence {
    return Intl.message(
      'Skip silence',
      name: 'SkipSilence',
      desc: '',
      args: [],
    );
  }

  /// `Skip sponsored segments in videos`
  String get SkipSponsoredSegmentsInVideos {
    return Intl.message(
      'Skip sponsored segments in videos',
      name: 'SkipSponsoredSegmentsInVideos',
      desc: '',
      args: [],
    );
  }

  /// `Song Cache`
  String get SongCache {
    return Intl.message(
      'Song Cache',
      name: 'SongCache',
      desc: '',
      args: [],
    );
  }

  /// `Song DNA`
  String get SongDNA {
    return Intl.message(
      'Song DNA',
      name: 'SongDNA',
      desc: '',
      args: [],
    );
  }

  /// `Song recognition (Echo Find)`
  String get SongRecognitionEchoFind {
    return Intl.message(
      'Song recognition (Echo Find)',
      name: 'SongRecognitionEchoFind',
      desc: '',
      args: [],
    );
  }

  /// `SponsorBlock (auto-skip)`
  String get SponsorBlockAutoSkip {
    return Intl.message(
      'SponsorBlock (auto-skip)',
      name: 'SponsorBlockAutoSkip',
      desc: '',
      args: [],
    );
  }

  /// `Stato Automix in sovrimpressione`
  String get StatoAutomixInSovrimpressione {
    return Intl.message(
      'Stato Automix in sovrimpressione',
      name: 'StatoAutomixInSovrimpressione',
      desc: '',
      args: [],
    );
  }

  /// `Stato, analisi beat, mix point e log eventi`
  String get StatoAnalisiBeatMixPointELogEventi {
    return Intl.message(
      'Stato, analisi beat, mix point e log eventi',
      name: 'StatoAnalisiBeatMixPointELogEventi',
      desc: '',
      args: [],
    );
  }

  /// `Streaming responses`
  String get StreamingResponses {
    return Intl.message(
      'Streaming responses',
      name: 'StreamingResponses',
      desc: '',
      args: [],
    );
  }

  /// `Streaming service configuration`
  String get StreamingServiceConfiguration {
    return Intl.message(
      'Streaming service configuration',
      name: 'StreamingServiceConfiguration',
      desc: '',
      args: [],
    );
  }

  /// `Supported Links`
  String get SupportedLinks {
    return Intl.message(
      'Supported Links',
      name: 'SupportedLinks',
      desc: '',
      args: [],
    );
  }

  /// `System update`
  String get SystemUpdate {
    return Intl.message(
      'System update',
      name: 'SystemUpdate',
      desc: '',
      args: [],
    );
  }

  /// `Target Language`
  String get TargetLanguage {
    return Intl.message(
      'Target Language',
      name: 'TargetLanguage',
      desc: '',
      args: [],
    );
  }

  /// `Test connection`
  String get TestConnection {
    return Intl.message(
      'Test connection',
      name: 'TestConnection',
      desc: '',
      args: [],
    );
  }

  /// `Theme`
  String get Theme {
    return Intl.message(
      'Theme',
      name: 'Theme',
      desc: '',
      args: [],
    );
  }

  /// `Themes, colors, and UI layout`
  String get ThemesColorsAndUILayout {
    return Intl.message(
      'Themes, colors, and UI layout',
      name: 'ThemesColorsAndUILayout',
      desc: '',
      args: [],
    );
  }

  /// `Translation`
  String get Translation {
    return Intl.message(
      'Translation',
      name: 'Translation',
      desc: '',
      args: [],
    );
  }

  /// `Translation Mode`
  String get TranslationMode {
    return Intl.message(
      'Translation Mode',
      name: 'TranslationMode',
      desc: '',
      args: [],
    );
  }

  /// `Trim silent parts (mpv silenceremove on desktop)`
  String get TrimSilentPartsMpvSilenceremoveOnDesktop {
    return Intl.message(
      'Trim silent parts (mpv silenceremove on desktop)',
      name: 'TrimSilentPartsMpvSilenceremoveOnDesktop',
      desc: '',
      args: [],
    );
  }

  /// `Use SSE for faster lyrics translation`
  String get UseSSEForFasterLyricsTranslation {
    return Intl.message(
      'Use SSE for faster lyrics translation',
      name: 'UseSSEForFasterLyricsTranslation',
      desc: '',
      args: [],
    );
  }

  /// `Verify the entered server credentials`
  String get VerifyTheEnteredServerCredentials {
    return Intl.message(
      'Verify the entered server credentials',
      name: 'VerifyTheEnteredServerCredentials',
      desc: '',
      args: [],
    );
  }

  /// `View your music listening statistics`
  String get ViewYourMusicListeningStatistics {
    return Intl.message(
      'View your music listening statistics',
      name: 'ViewYourMusicListeningStatistics',
      desc: '',
      args: [],
    );
  }

  /// `Your year in sound & personal music recap`
  String get YourYearInSoundPersonalMusicRecap {
    return Intl.message(
      'Your year in sound & personal music recap',
      name: 'YourYearInSoundPersonalMusicRecap',
      desc: '',
      args: [],
    );
  }

  /// `Join room`
  String get JoinRoom {
    return Intl.message('Join room', name: 'JoinRoom', desc: '', args: []);
  }
  /// `Pending requests`
  String get PendingRequests {
    return Intl.message('Pending requests', name: 'PendingRequests', desc: '', args: []);
  }

  /// `Add audio files`
  String get AddAudioFiles {
    return Intl.message(
      'Add audio files',
      name: 'AddAudioFiles',
      desc: '',
      args: [],
    );
  }
  /// `Add downloaded songs`
  String get AddDownloadedSongs {
    return Intl.message(
      'Add downloaded songs',
      name: 'AddDownloadedSongs',
      desc: '',
      args: [],
    );
  }
  /// `No exports yet`
  String get NoExportsYet {
    return Intl.message(
      'No exports yet',
      name: 'NoExportsYet',
      desc: '',
      args: [],
    );
  }
  /// `No downloaded songs`
  String get NoDownloadedSongs {
    return Intl.message(
      'No downloaded songs',
      name: 'NoDownloadedSongs',
      desc: '',
      args: [],
    );
  }
  /// `Download manager unavailable`
  String get DownloadManagerUnavailable {
    return Intl.message(
      'Download manager unavailable',
      name: 'DownloadManagerUnavailable',
      desc: '',
      args: [],
    );
  }
  /// `Exporting to MP3`
  String get ExportingToMp3 {
    return Intl.message(
      'Exporting to MP3',
      name: 'ExportingToMp3',
      desc: '',
      args: [],
    );
  }
  /// `MP3 saved to your Music folder`
  String get ExportSavedToFolder {
    return Intl.message(
      'MP3 saved to your Music folder',
      name: 'ExportSavedToFolder',
      desc: '',
      args: [],
    );
  }
  /// `Export failed`
  String get ExportFailed {
    return Intl.message(
      'Export failed',
      name: 'ExportFailed',
      desc: '',
      args: [],
    );
  }
  /// `Open folder`
  String get OpenFolder {
    return Intl.message(
      'Open folder',
      name: 'OpenFolder',
      desc: '',
      args: [],
    );
  }
  /// `Download complete`
  String get DownloadComplete {
    return Intl.message(
      'Download complete',
      name: 'DownloadComplete',
      desc: '',
      args: [],
    );
  }
  /// `Download failed`
  String get DownloadFailed {
    return Intl.message(
      'Download failed',
      name: 'DownloadFailed',
      desc: '',
      args: [],
    );
  }
  /// `Stem separation Python`
  String get StemSeparationPython {
    return Intl.message(
      'Stem separation Python',
      name: 'StemSeparationPython',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'es'),
      Locale.fromSubtags(languageCode: 'hi'),
      Locale.fromSubtags(languageCode: 'it'),
      Locale.fromSubtags(languageCode: 'tr'),
      Locale.fromSubtags(languageCode: 'ur'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
