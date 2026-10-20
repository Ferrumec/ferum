use authnz::AuthnModule;
use authz::Module as AuthzModule;
use blogs::Module as BlogsModule;
use dotenvy::dotenv;
use ferrumec::{LocalInfra, launch, modules};
use notification::NotificationModule;
use s3_upload::Module as FilesModule;

#[actix_web::main]
async fn main() {
    dotenv().ok();
    let infra = LocalInfra::new().await.expect("coould not connect infra");
    let modls = modules![infra.clone();("auth",AuthnModule),("blogs",BlogsModule),("permissions",AuthzModule),("notifications",NotificationModule),("files",FilesModule)].expect("could not bundle modules");
    launch::launch(modls, infra).await;
}
