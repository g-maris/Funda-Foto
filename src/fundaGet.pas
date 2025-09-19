{
 Program : FUNDA Foto Downloader
 Created : Sept 2025
 File    : fundaGet.pas
 Author  : Guy Maris
 Target  : Native code for Windows Server and Linux (Debian/Ubuntu)
 Language: Object Pascal
 Compiler: FreePascal V3.2.2
 Remarks : Windows run-time dependency on OpenSSL (libeay32.dll + ssleay32.dll)
}
PROGRAM fundaGet;
{$mode objfpc}{$H+}{$ifdef windows}{$apptype console}{$endif}

USES
  sysutils, classes, fphttpclient, openssl, opensslsockets;

VAR
  i, p       : integer;
  response,
  house, url,
  folder,
  fname      : string;
  elements   : array of string;
  stream     : TStream;
  http       : TFPHttpClient;

BEGIN
  writeln('FUNDA Foto Downloader, V1.2, (c) Guy Maris');

  house := ParamStr(1);
  folder:= ParamStr(2);

  if ParamCount = 0 then
  begin
    write('House url : '); readln(house);
    write('Folder    : '); readln(folder);
  end;

  if length(folder) > 0 then
    if NOT folder.EndsWith('\') then folder += '\';

  // https://www.funda.nl/detail/koop/waddinxveen/huis-zuidkade-9/89472794/
  elements:=house.split('/');
  if length(elements) < 9 then
  begin writeln('Usage: fundaGet https://www.funda.nl/detail/koop/<city>/<street>/<id>/ [<folder>]'); HALT; end;

  writeln('City  : ',elements[5]);
  writeln('Street: ',elements[6]);

  InitSSLInterface;

  // Get foto index (Alle media)
  http:=TFPHttpClient.Create(nil);
  try
    try
      http.AddHeader('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
      http.AddHeader('Accept', '*/*');
      http.AddHeader('Accept-Encoding', '');
      http.AddHeader('Accept-Language', 'en-US,en;q=0.9,nl;q=0.8');
      http.AddHeader('Sec-Ch-Ua', '"Chromium";v="140", "Not=A?Brand";v="24", "Microsoft Edge";v="140"');
      http.AddHeader('Sec-Ch-Ua-Mobile', '?0');
      http.AddHeader('Sec-Ch-Ua-Platform', '"Windows"');
      http.AllowRedirect:=true;
      response:=http.Get(house + '/overzicht');
    //response:=http.Get('https://inspect.eu1.phsdp.com/dump');
    except
      on E: EHttpClient do begin writeln(E.Message); HALT(1); end else raise;
    end;
  finally
    http.Free;
  end;

  i:=0; // foto count

  // Parse foto index
  REPEAT
    p:=pos('src="', response);
    if p > 0 then
    begin
      delete(response,1,p+4);
      p  := pos('.jpg?', response);
      url:= copy(response,1,p+3);
      if (pos('https://cloud.funda.nl/', url) = 1) AND (length(url) = 54) then
      begin
        fname:=StringReplace(copy(url,40,20), '/', '-', [rfReplaceAll]);
        try
          stream:=TFileStream.Create(folder + fname, fmCreate or fmOpenWrite);
        except
           on E: EFOpenError do begin writeln(E.Message); HALT(1); end else raise;
        end;
        inc(i); writeln(i:4, ' ', folder, fname);
        // Download foto (e.g. https://cloud.funda.nl/valentina_media/215/673/110.jpg)
        http:=TFPHttpClient.Create(nil);
        try
          try
            http.AllowRedirect:=true;
            http.Get(url, stream);
          except
            on E: EHttpClient do begin writeln(E.Message); HALT(1); end else raise;
          end;
        finally
          stream.Free; http.Free;
        end;
      end;
    end;
  UNTIL p=0;

  writeln('Done!');

END.