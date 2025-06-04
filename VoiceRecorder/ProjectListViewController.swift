import Foundation

class ProjectListViewController: ObservableObject {
    @Published var projects: [ProjectView] = []
    private let userDefaults = UserDefaults.standard
    private let projectsKey = "SavedProjects"
    
    init() {
        loadProjects()
    }
    
    func createNewProject(name: String = "") -> ProjectView {
        let project = ProjectView(name: name)
        projects.insert(project, at: 0) // Add to beginning
        saveProjects()
        return project
    }
    
    func deleteProject(_ project: ProjectView) {
        projects.removeAll { $0.id == project.id }
        saveProjects()
    }
    
    func renameProject(_ project: ProjectView, to newName: String) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].rename(to: newName)
            saveProjects()
        }
    }
    
    private func saveProjects() {
        if let encoded = try? JSONEncoder().encode(projects) {
            userDefaults.set(encoded, forKey: projectsKey)
        }
    }
    
    private func loadProjects() {
        if let data = userDefaults.data(forKey: projectsKey),
           let decoded = try? JSONDecoder().decode([ProjectView].self, from: data) {
            projects = decoded
        }
    }
}
