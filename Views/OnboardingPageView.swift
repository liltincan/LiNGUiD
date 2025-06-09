import SwiftUI

struct OnboardingPageView: View {
    let index: Int

    var body: some View {
        ZStack{
            Color.black.edgesIgnoringSafeArea(.all)
            VStack(spacing: 00) {

                Group {
                    switch index {
                    case 0:
                        VStack(spacing: 00) {
                            Text("Select your native Language")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.top, 20)
                                .drawingGroup()
                            
                            Text("You may select one or more")
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.top, 10)
                                .drawingGroup()
                            
                        }
                        
                        
                        
                    case 1:
                        VStack(spacing: 00) {
                            Text("Select your \n target Language")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.top, 20)
                                .drawingGroup()
                            
                        }

                    case 2:
                        VStack(spacing: 00) {
                            Image("AppLogoPdf")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 290, height: 100, alignment: .center) // Adjust size as needed
                                .padding(.top, 30)
                        }
                        
                        Spacer(minLength: 50)
                        ZStack(){
                            VStack(spacing: 00) {
                                Text("Zero to Fluent\nthe easy way")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .drawingGroup()
                                
                                Text("\nTo get the most out of LiNGUiD, stop\ncaring about understanding every word.\nThe more relaxed you are, the more\nefficiently you will acquire your target\nlanguage. LiNGUiD is the best way to\nachieve true immersion. Forget\ndoomscrolling. From now on, you will be\nlanguage scrolling to fluency. Now all\nthe time you spend swiping will be time\nspent acquiring.\n")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                                    .drawingGroup()
                            }
                            .padding()
                            .background(Color(red: 62/255, green: 29/255, blue: 119/255))
                            .cornerRadius(8)
                            .padding()

                        }
                        Spacer()
                        
                        
                    default:
                        Text("Unknown Page")
                            .foregroundColor(.red)
                    }
                }
                Spacer()
            }
        }
    }
}


//struct OnboardingPageView_Previews: PreviewProvider {
//    static var previews: some View {
//        OnboardingPageView(index: 2)
//    }
//}
