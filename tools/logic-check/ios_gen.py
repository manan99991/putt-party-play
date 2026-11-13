import re,sys,os
HERE=os.path.dirname(os.path.abspath(__file__))
I=os.path.join(HERE,'..','..','ios')+'/'
W=sys.argv[1]
os.makedirs(W,exist_ok=True)
def decl(src, start, nth=0):
    idx=-1
    for _ in range(nth+1):
        idx=src.index(start, idx+1)
    ls=src.rfind('\n',0,idx)+1
    i=src.index('{',idx); d=0
    while True:
        c=src[i]
        if c=='{': d+=1
        elif c=='}':
            d-=1
            if d==0: break
        i+=1
    return src[ls:i+1]+'\n'
cr=open(I+'HandyTools/Engines/ChainRunner.swift').read()
out=['import Foundation\n']
a=cr.index('enum ChainPayload'); b=cr.index('enum ChainRunner {')
out.append(cr[a:b])
out.append('enum ChainRunner { enum Failure: Error, Equatable { case invalid(String), wrongInput(Block), nothingFound(Block), failed(Block) } }\n')
for m in ['enum ChainTemplates {','extension Chain {\n    static let prefix','struct StampPlan: Equatable','enum ChainName {','enum RunningList {','enum StampBook {','enum ToolLink {','enum BuilderLimits {','extension Block {\n    /// The basic steps','extension Chain {\n    /// The Pro steps']:
    out.append(decl(cr,m))
ct='enum ChainText {\n'
for f in ['static func scamReport(','static func cleanLinks(','private static func full(','static func chatLink(','static func callingCode(','static let returnWindows','static let videoLimits','static func videoLimit(','static func returnDays(','static func returnDeadline(','static func returnTitle(','static func wifi(in','static func wifiCode(','static let trimLengths','static func trimWindow(','static func turnDegrees(','static let pdfLimits','static func pdfLimit(','static func pageList(','static let languages','static func languageName(','static func languageCode(','static let rewriteStyles','static func rewriteStyle(','static func rewriteAsk(','static func captionLines(','static func pageLink(','static func article(','static func collageGrid(','static func autoName(','static func toolName(','static func savedName(','static func locationText(','static let faceEmojis','static func faceEmoji(','static func memeText(','static let speeds','static func speedRate(','static func loopOrder(','static func mosaicGrid(','static let mosaicEmojis','static func nearestColor(','static let voices','static func voiceRate(','static func wavHeader(']:
    if f.startswith('static let'):
        i=cr.index(f); e=cr.index('\n',i)
        if cr[i:e].rstrip().endswith('['): e=cr.index('\n    ]',e)+6      # a list written over several lines
        ct+='    '+cr[i:e]+'\n'
    else: ct+=decl(cr,f)
ct+='}\n'
out.append(ct)
out.append(open(I+'HandyTools/Engines/TextTidy.swift').read().replace('import Foundation',''))
out.append(open(I+'HandyTools/Engines/PixelArt.swift').read().replace('import Foundation',''))
bi=open(I+'HandyTools/Tools/BuilderInputs.swift').read(); out.append(decl(bi,'enum InputText {'))
bn=open(I+'HandyTools/Tools/BuilderIntro.swift').read(); out.append(decl(bn,'enum BuilderIntro {'))
bs=open(I+'HandyTools/Tools/BuilderSheets.swift').read(); out.append('enum SheetsView {\n'+decl(bs,'static func summary(')+'}\n')
sc=open(I+'HandyTools/Tools/BuilderSchedule.swift').read()
out.append('enum ToolSchedules {\n    static let prefix = "tool-"\n    static let limit = 56\n'+decl(sc,'static func plan(')+'}\n')
out.append('''
final class UIImage { var size = CGSize.zero }
enum AppGroup { static let id = "group.test"; static let defaults = UserDefaults.standard }
enum ImageStudio { enum Format: String, CaseIterable { case jpg = "JPG", png = "PNG" } }
''')
out.append(open(I+'HandyTools/Engines/ChainPlanner.swift').read().replace('import FoundationModels','').replace('import Foundation',''))
for e in ['DataGrab','LinkCleaner','ScamAnalyzer']: out.append(open(I+'HandyTools/Engines/'+e+'.swift').read().replace('import Foundation',''))
out.append(open(os.path.join(HERE,'ios_stubs.swift')).read())
src=''.join(out)
src=src.replace('FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)','Optional<URL>.none')
open(os.path.join(W,'app.swift'),'w').write(src)

t=open(I+'HandyToolsTests/ChainRunnerTests.swift').read()
bad=['ChainRunner.apply','ChainRunner.run','await','ChainImage','ChainCombine','UIGraphics','PDFDocument','DocEngine','ToolIntentSupport','PDFInput','ChainPlanner.plan(','ChainStore','ContactsTransfer','UIColor','CGRect','Outbox','BatchItem','ChainText.best','ChainText.qr','PriceBrain','BlockStyle','.icon','.tint','.blurb','SendSheet','failureValue','Given.','ChainFun','ChainMedia','RunHistory','HistoryItem']
tests=[]; runner=[]; skipped=[]
for cm in re.finditer(r'^final class (\w+): XCTestCase \{', t, re.M):
    body=decl(t, cm.group(0)); name=cm.group(1); kept=[]; names=[]
    inner=body[body.index('{')+1:body.rindex('}')]
    pos=0
    while True:
        m=re.search(r'^    (?:private )?(?:static )?(func|let|var) ', inner[pos:], re.M)
        if not m: break
        st=pos+m.start()
        if m.group(1)=='func':
            d=decl(inner[st:], 'func ')
            pos=st+len(d)
            fm=re.match(r'\s*func (\w+)\(', d)
            if any(x in d for x in bad):
                skipped.append(name+'.'+(fm.group(1) if fm else '?')); continue
            kept.append(d)
            if fm and fm.group(1).startswith('test'): names.append(fm.group(1))
        else:
            e=inner.index('\n',st); ln=inner[st:e+1]; pos=e+1
            if any(x in ln for x in bad): continue
            kept.append(ln)
    if names:
        tests.append('final class %s: XCTestCase {\n%s}\n'%(name,''.join(kept)))
        for n in names: runner.append('run("%s.%s") { try %s().%s() }'%(name,n,name,n))
open(os.path.join(W,'tests.swift'),'w').write('import Foundation\n'+'\n'.join(tests))
open(os.path.join(W,'main.swift'),'w').write('import Foundation\n'+'\n'.join(runner)+'\nprint("passed \\(passed) failed \\(failures.count)")\nfor f in failures { print("FAIL", f) }\n')
print(len(runner),'tests run;',len(skipped),'need a phone:',', '.join(skipped) if '-v' in sys.argv else '')

import shutil; shutil.copy(os.path.join(HERE,'ios_shim.swift'), os.path.join(W,'shim.swift'))
