public protocol ProgressPlugin: PluginType {
    func uploadProgress(_ progress: RequestProgress, snapshot: RequestContext.Snapshot)
    func downloadProgress(_ progress: RequestProgress, snapshot: RequestContext.Snapshot)
}
