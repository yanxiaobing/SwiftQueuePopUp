Pod::Spec.new do |popup|
    popup.name         = 'SwiftQueuePopUp'
    popup.version      = '1.5.1'
    popup.summary      = '1：修复导航栈丢失问题  2：新增BottomToTopTransition'
    popup.homepage     = 'https://github.com/yanxiaobing/SwiftQueuePopUp'
    popup.license      = 'MIT'
    popup.authors      = {'XBingo' => 'dove025@qq.com'}
    popup.platform     = :ios, '11.0'
    popup.source       = {:git => 'https://github.com/yanxiaobing/SwiftQueuePopUp.git', :tag => popup.version}
    popup.requires_arc = true
    popup.swift_version = '5.0'
    popup.source_files     = 'SwiftQueuePopUp/*.swift'
    
end
