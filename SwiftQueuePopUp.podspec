Pod::Spec.new do |popup|
    popup.name         = 'SwiftQueuePopUp'
    popup.version      = '1.4.0'
    popup.summary      = '1：空白点击优化 2：增加window上弹窗 3:修复window方式didHideBlock不回调的问题'
    popup.homepage     = 'https://github.com/yanxiaobing/SwiftQueuePopUp'
    popup.license      = 'MIT'
    popup.authors      = {'XBingo' => 'dove025@qq.com'}
    popup.platform     = :ios, '8.0'
    popup.source       = {:git => 'https://github.com/yanxiaobing/SwiftQueuePopUp.git', :tag => popup.version}
    popup.requires_arc = true
    popup.swift_version = '4.2'
    popup.source_files     = 'SwiftQueuePopUp/*.swift'
    
end
