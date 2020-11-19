Pod::Spec.new do |popup|
    popup.name         = 'SwiftQueuePopUp'
    popup.version      = '1.1.0'
    popup.summary      = '1：通过VC基类的方式将弹窗的相关属性内聚，便于使用约束布局，简化使用'
    popup.homepage     = 'https://github.com/yanxiaobing/SwiftQueuePopUp'
    popup.license      = 'MIT'
    popup.authors      = {'XBingo' => 'dove025@qq.com'}
    popup.platform     = :ios, '8.0'
    popup.source       = {:git => 'https://github.com/yanxiaobing/SwiftQueuePopUp.git', :tag => popup.version}
    popup.requires_arc = true
    popup.swift_version = '4.2'
    popup.source_files     = 'SwiftQueuePopUp/*.swift'
    
end
