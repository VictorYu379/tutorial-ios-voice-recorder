import Foundation

class ProjectListViewController: ObservableObject {
    public static let DEFAULT_PROJECT_NAME = "Untitled Project"
    @Published var projects: [UUID: ProjectInfo] = [:]

    private let userDefaults = UserDefaults.standard
    private let projectsKey = "SavedProjects"
    
    init() {
        loadProjects()
    }
    
    func createNewProject(name: String = "") -> ProjectInfo {
        // Trim whitespace and provide better default if empty
        let projectName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = projectName.isEmpty ? ProjectListViewController.DEFAULT_PROJECT_NAME : projectName
        
        let project = ProjectInfo(name: finalName)
        projects[project.id] = project
        print("Created project \(project.id) with name \(project.name)")
        saveProjects()
        return project
    }
    
    func deleteProject(_ project: ProjectInfo) {
        projects.removeValue(forKey: project.id)
        saveProjects()
    }
    
    func renameProject(projectId: UUID, to newName: String) {
        print("Renaming project \(projectId) to \(newName)")
        projects[projectId]?.rename(to: newName)
        saveProjects()
    }
    
    private func saveProjects() {
        if let encoded = try? JSONEncoder().encode(projects) {
            userDefaults.set(encoded, forKey: projectsKey)
        }
    }
    
    private func loadProjects() {
        if let data = userDefaults.data(forKey: projectsKey),
           let decoded = try? JSONDecoder().decode([UUID: ProjectInfo].self, from: data) {
            projects = decoded
        }
    }
}
